// Webcam helper — reads from the live /dev/video0 and runs YOLO/pose/emotion.
// This wraps the existing webcam module's public API.

use std::time::Duration;

/// Wait for the webcam pipeline to produce detections, then return them.
pub fn wait_for_detections(timeout_secs: u64) -> Vec<String> {
    let start = std::time::Instant::now();
    while start.elapsed().as_secs() < timeout_secs {
        let dets = aura_lnn::vision::store::get_latest_webcam_detections();
        if !dets.is_empty() {
            return dets.iter().map(|d| format!("{} ({:.2})", d.label, d.confidence)).collect();
        }
        std::thread::sleep(Duration::from_millis(500));
    }
    Vec::new()
}

/// Check the latest scene summary (includes emotion + activity).
pub fn get_scene() -> String {
    aura_lnn::vision::store::get_latest_webcam_scene()
}

/// Check for pending gesture (wave/open_palm from pose model).
pub fn get_gesture() -> Option<String> {
    let g = aura_lnn::vision::webcam::take_pending_gesture();
    if g.is_empty() { None } else { Some(g) }
}
