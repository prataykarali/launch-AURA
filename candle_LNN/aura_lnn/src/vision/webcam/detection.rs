use ndarray::Array4;
use ort::session::Session;
use ort::value::TensorRef;

use crate::vision::events::VisionDetection;
use crate::vision::webcam::capture::resize_rgb;
use crate::vision::webcam::model::COCO_CLASSES;

#[derive(Debug, Clone)]
pub struct Detection {
    pub x1: f32,
    pub y1: f32,
    pub x2: f32,
    pub y2: f32,
    pub class_id: usize,
    pub score: f32,
}

pub fn infer_detections(
    session: &mut Session,
    rgb: &[u8],
    cam_w: usize,
    cam_h: usize,
) -> anyhow::Result<Vec<VisionDetection>> {
    let resized = resize_rgb(rgb, cam_w, cam_h, 640, 640);

    // Input is [1, 3, 640, 640] normalized float tensor
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
        .map_err(|e| anyhow::anyhow!("ort input tensor: {e}"))?;
    let outputs = session
        .run(ort::inputs![input_ref])
        .map_err(|e| anyhow::anyhow!("ort run: {e}"))?;
    let (_out_shape, logits) = outputs[0]
        .try_extract_tensor::<f32>()
        .map_err(|e| anyhow::anyhow!("ort extract: {e}"))?;

    let mut raw_detections = Vec::new();
    for col in 0..8400 {
        let mut max_score = 0.0f32;
        let mut class_id = 0;
        for class_row in 4..84 {
            let score = logits[class_row * 8400 + col];
            if score > max_score {
                max_score = score;
                class_id = class_row - 4;
            }
        }
        if max_score > 0.25 {
            let cx = logits[col];
            let cy = logits[8400 + col];
            let w = logits[2 * 8400 + col];
            let h = logits[3 * 8400 + col];
            raw_detections.push(Detection {
                x1: cx - w / 2.0,
                y1: cy - h / 2.0,
                x2: cx + w / 2.0,
                y2: cy + h / 2.0,
                class_id,
                score: max_score,
            });
        }
    }

    let detections = nms(raw_detections, 0.45);
    let mut vision_detections = Vec::new();
    for d in detections {
        let x1 = d.x1.clamp(0.0, 640.0) * (cam_w as f32 / 640.0);
        let y1 = d.y1.clamp(0.0, 640.0) * (cam_h as f32 / 640.0);
        let x2 = d.x2.clamp(0.0, 640.0) * (cam_w as f32 / 640.0);
        let y2 = d.y2.clamp(0.0, 640.0) * (cam_h as f32 / 640.0);

        let label = COCO_CLASSES
            .get(d.class_id)
            .copied()
            .unwrap_or("unknown")
            .to_string();
        vision_detections.push(VisionDetection {
            label,
            confidence: d.score,
            bbox: Some([x1, y1, x2, y2]),
        });
    }
    Ok(vision_detections)
}

pub fn nms(mut detections: Vec<Detection>, iou_threshold: f32) -> Vec<Detection> {
    detections.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut kept = Vec::new();
    let mut suppressed = vec![false; detections.len()];

    for i in 0..detections.len() {
        if suppressed[i] {
            continue;
        }
        let det_i = &detections[i];
        kept.push(det_i.clone());
        for j in (i + 1)..detections.len() {
            if suppressed[j] {
                continue;
            }
            let det_j = &detections[j];
            if det_i.class_id == det_j.class_id {
                let iou = intersection_over_union(det_i, det_j);
                if iou > iou_threshold {
                    suppressed[j] = true;
                }
            }
        }
    }
    kept
}

pub fn intersection_over_union(a: &Detection, b: &Detection) -> f32 {
    let x1 = a.x1.max(b.x1);
    let y1 = a.y1.max(b.y1);
    let x2 = a.x2.min(b.x2);
    let y2 = a.y2.min(b.y2);

    let intersection_width = (x2 - x1).max(0.0);
    let intersection_height = (y2 - y1).max(0.0);
    let intersection_area = intersection_width * intersection_height;

    let area_a = (a.x2 - a.x1) * (a.y2 - a.y1);
    let area_b = (b.x2 - b.x1) * (b.y2 - b.y1);
    let union_area = area_a + area_b - intersection_area;

    if union_area <= 0.0 {
        return 0.0;
    }
    intersection_area / union_area
}
