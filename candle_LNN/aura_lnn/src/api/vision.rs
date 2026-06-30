use super::{EngineMsg, TX};
use crate::vision::VisionDetection;

pub fn aura_process_vision(detections: Vec<VisionDetection>) -> bool {
    match TX.get() {
        None => false,
        Some(tx) => tx.try_send(EngineMsg::VisionEvent { detections }).is_ok(),
    }
}

/// Returns a pending webcam gesture label (e.g. "wave") if the webcam thread
/// detected one since the last call, then clears it. Empty string otherwise.
/// Dart polls this on a short timer to trigger immediate gesture greetings.
/// Each call also (re)starts/extends the headless gesture-watch session so the
/// camera stays alive for wave detection while the bar is polling.
pub fn aura_get_webcam_gesture() -> String {
    crate::vision::webcam::start_gesture_watch();
    crate::vision::webcam::take_pending_gesture()
}
