use ndarray::Array4;
use ort::session::Session;
use ort::value::TensorRef;

use crate::vision::events::VisionDetection;
use crate::vision::webcam::model::EMOTION_LABELS;

pub fn infer_expression_detections(
    session: &mut Session,
    rgb: &[u8],
    cam_w: usize,
    cam_h: usize,
    detections: &[VisionDetection],
) -> anyhow::Result<Vec<VisionDetection>> {
    let person_bbox = detections
        .iter()
        .find(|d| d.label == "person")
        .and_then(|d| d.bbox)
        .unwrap_or([0.0, 0.0, cam_w as f32, cam_h as f32]);
    let face_bbox = estimate_face_bbox(person_bbox, cam_w, cam_h);
    let crop = crop_resize_grayscale(rgb, cam_w, cam_h, face_bbox, 64, 64);
    let mut input_tensor = Array4::<f32>::zeros((1, 1, 64, 64));
    for y in 0..64 {
        for x in 0..64 {
            input_tensor[[0, 0, y, x]] = crop[y * 64 + x] as f32;
        }
    }

    let input_ref = TensorRef::from_array_view(&input_tensor)
        .map_err(|e| anyhow::anyhow!("ort expression input tensor: {e}"))?;
    let outputs = session
        .run(ort::inputs![input_ref])
        .map_err(|e| anyhow::anyhow!("ort expression run: {e}"))?;
    let (_out_shape, logits) = outputs[0]
        .try_extract_tensor::<f32>()
        .map_err(|e| anyhow::anyhow!("ort expression extract: {e}"))?;
    if logits.len() < EMOTION_LABELS.len() {
        anyhow::bail!("unexpected expression output length: {}", logits.len());
    }

    let probs = softmax(&logits[..EMOTION_LABELS.len()]);
    let mut best_idx = 0;
    let mut best = 0.0f32;
    for (idx, prob) in probs.iter().enumerate() {
        if *prob > best {
            best = *prob;
            best_idx = idx;
        }
    }

    let mut result = vec![VisionDetection {
        label: "face_visible".to_string(),
        confidence: 0.55,
        bbox: Some(face_bbox),
    }];
    if best >= 0.34 {
        let label = match EMOTION_LABELS[best_idx] {
            "happiness" => "smiling",
            "surprise" => "surprised_expression",
            "sadness" => "tired_or_sad_expression",
            "anger" | "disgust" | "fear" | "contempt" => "strained_expression",
            _ => "focused_expression",
        };
        result.push(VisionDetection {
            label: label.to_string(),
            confidence: best.clamp(0.0, 0.9),
            bbox: Some(face_bbox),
        });
    }
    Ok(result)
}

pub fn estimate_face_bbox(person_bbox: [f32; 4], cam_w: usize, cam_h: usize) -> [f32; 4] {
    let width = person_bbox[2] - person_bbox[0];
    let height = person_bbox[3] - person_bbox[1];
    let face_w = width * 0.45;
    let face_h = height * 0.32;
    let cx = (person_bbox[0] + person_bbox[2]) / 2.0;
    let y1 = person_bbox[1] + height * 0.03;
    [
        (cx - face_w / 2.0).clamp(0.0, cam_w as f32 - 1.0),
        y1.clamp(0.0, cam_h as f32 - 1.0),
        (cx + face_w / 2.0).clamp(0.0, cam_w as f32 - 1.0),
        (y1 + face_h).clamp(0.0, cam_h as f32 - 1.0),
    ]
}

pub fn crop_resize_grayscale(
    rgb: &[u8],
    src_w: usize,
    src_h: usize,
    bbox: [f32; 4],
    dst_w: usize,
    dst_h: usize,
) -> Vec<u8> {
    let mut dst = vec![0u8; dst_w * dst_h];
    let x1 = bbox[0].max(0.0) as usize;
    let y1 = bbox[1].max(0.0) as usize;
    let x2 = bbox[2].min(src_w as f32 - 1.0).max(bbox[0] + 1.0) as usize;
    let y2 = bbox[3].min(src_h as f32 - 1.0).max(bbox[1] + 1.0) as usize;
    for y in 0..dst_h {
        let src_y = y1 + (y * (y2.saturating_sub(y1).max(1))) / dst_h;
        for x in 0..dst_w {
            let src_x = x1 + (x * (x2.saturating_sub(x1).max(1))) / dst_w;
            let idx = (src_y * src_w + src_x) * 3;
            if idx + 2 < rgb.len() {
                let r = rgb[idx] as f32;
                let g = rgb[idx + 1] as f32;
                let b = rgb[idx + 2] as f32;
                dst[y * dst_w + x] = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 255.0) as u8;
            }
        }
    }
    dst
}

pub fn softmax(values: &[f32]) -> Vec<f32> {
    let max = values
        .iter()
        .copied()
        .fold(f32::NEG_INFINITY, |a, b| a.max(b));
    let exps: Vec<f32> = values.iter().map(|v| (*v - max).exp()).collect();
    let sum: f32 = exps.iter().sum();
    if sum <= 0.0 {
        return vec![0.0; values.len()];
    }
    exps.into_iter().map(|v| v / sum).collect()
}
