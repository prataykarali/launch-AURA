use ndarray::Array4;
use ort::session::Session;
use ort::value::TensorRef;

use crate::vision::events::VisionDetection;
use crate::vision::webcam::capture::resize_rgb;

#[derive(Debug, Clone)]
pub struct PoseCandidate {
    pub bbox: [f32; 4],
    pub score: f32,
    pub keypoints: [(f32, f32, f32); 17],
}

pub fn infer_pose_detections(
    session: &mut Session,
    rgb: &[u8],
    cam_w: usize,
    cam_h: usize,
) -> anyhow::Result<Vec<VisionDetection>> {
    let resized = resize_rgb(rgb, cam_w, cam_h, 640, 640);

    let mut input_tensor = Array4::<f32>::zeros((1, 3, 640, 640));
    for y in 0..640 {
        for x in 0..640 {
            let idx = (y * 640 + x) * 3;
            input_tensor[[0, 0, y, x]] = resized[idx] as f32 / 255.0;
            input_tensor[[0, 1, y, x]] = resized[idx + 1] as f32 / 255.0;
            input_tensor[[0, 2, y, x]] = resized[idx + 2] as f32 / 255.0;
        }
    }

    let input_ref = TensorRef::from_array_view(&input_tensor)
        .map_err(|e| anyhow::anyhow!("ort pose input tensor: {e}"))?;
    let outputs = session
        .run(ort::inputs![input_ref])
        .map_err(|e| anyhow::anyhow!("ort pose run: {e}"))?;
    let (out_shape, logits) = outputs[0]
        .try_extract_tensor::<f32>()
        .map_err(|e| anyhow::anyhow!("ort pose extract: {e}"))?;

    if out_shape.len() < 3 {
        anyhow::bail!("unexpected pose output shape: {:?}", out_shape);
    }
    let rows = out_shape[out_shape.len() - 2] as usize;
    let cols = out_shape[out_shape.len() - 1] as usize;
    if rows < 56 {
        anyhow::bail!("unexpected pose output rows: {}", rows);
    }

    let mut candidates = Vec::new();
    for col in 0..cols {
        let score = logits[4 * cols + col];
        if score < 0.35 {
            continue;
        }
        let cx = logits[col];
        let cy = logits[cols + col];
        let w = logits[2 * cols + col];
        let h = logits[3 * cols + col];
        let mut keypoints = [(0.0f32, 0.0f32, 0.0f32); 17];
        for (idx, point) in keypoints.iter_mut().enumerate() {
            let base = 5 + idx * 3;
            if base + 2 >= rows {
                break;
            }
            *point = (
                logits[base * cols + col],
                logits[(base + 1) * cols + col],
                logits[(base + 2) * cols + col],
            );
        }
        candidates.push(PoseCandidate {
            bbox: [cx - w / 2.0, cy - h / 2.0, cx + w / 2.0, cy + h / 2.0],
            score,
            keypoints,
        });
    }

    candidates.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let mut detections = Vec::new();
    if let Some(candidate) = candidates.first() {
        let mut labels = vec![VisionDetection {
            label: "body_pose".to_string(),
            confidence: candidate.score,
            bbox: Some(scale_bbox(candidate.bbox, cam_w, cam_h)),
        }];
        labels.append(&mut pose_labels(candidate, cam_w, cam_h));
        detections.append(&mut labels);
    }
    Ok(detections)
}

pub fn pose_labels(candidate: &PoseCandidate, cam_w: usize, cam_h: usize) -> Vec<VisionDetection> {
    let mut labels = Vec::new();
    let left_shoulder = candidate.keypoints[5];
    let right_shoulder = candidate.keypoints[6];
    let left_wrist = candidate.keypoints[9];
    let right_wrist = candidate.keypoints[10];

    let shoulder_y = visible_mid_y(left_shoulder, right_shoulder);
    let mut raised_hands = 0;
    let mut hand_bbox = candidate.bbox;
    for point in [left_wrist, right_wrist] {
        if point.2 >= 0.35 {
            hand_bbox = include_point(hand_bbox, point.0, point.1);
            if shoulder_y.map(|y| point.1 < y - 20.0).unwrap_or(false) {
                raised_hands += 1;
            }
        }
    }

    if raised_hands > 0 {
        labels.push(VisionDetection {
            label: if raised_hands >= 2 {
                "hands_raised".to_string()
            } else {
                "hand_pose".to_string()
            },
            confidence: candidate.score.min(0.9),
            bbox: Some(scale_bbox(hand_bbox, cam_w, cam_h)),
        });
    }

    if raised_hands > 0 && candidate.score >= 0.45 {
        labels.push(VisionDetection {
            label: "open_palm_or_wave_pose".to_string(),
            confidence: (candidate.score * 0.9).min(0.86),
            bbox: Some(scale_bbox(hand_bbox, cam_w, cam_h)),
        });
    }

    labels
}

pub fn visible_mid_y(a: (f32, f32, f32), b: (f32, f32, f32)) -> Option<f32> {
    match (a.2 >= 0.35, b.2 >= 0.35) {
        (true, true) => Some((a.1 + b.1) / 2.0),
        (true, false) => Some(a.1),
        (false, true) => Some(b.1),
        (false, false) => None,
    }
}

pub fn include_point(mut bbox: [f32; 4], x: f32, y: f32) -> [f32; 4] {
    bbox[0] = bbox[0].min(x);
    bbox[1] = bbox[1].min(y);
    bbox[2] = bbox[2].max(x);
    bbox[3] = bbox[3].max(y);
    bbox
}

pub fn scale_bbox(bbox: [f32; 4], cam_w: usize, cam_h: usize) -> [f32; 4] {
    [
        bbox[0].clamp(0.0, 640.0) * (cam_w as f32 / 640.0),
        bbox[1].clamp(0.0, 640.0) * (cam_h as f32 / 640.0),
        bbox[2].clamp(0.0, 640.0) * (cam_w as f32 / 640.0),
        bbox[3].clamp(0.0, 640.0) * (cam_h as f32 / 640.0),
    ]
}
