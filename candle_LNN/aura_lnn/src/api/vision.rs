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
    if std::env::var("AURA_CAMERA_OFF").as_deref() == Ok("1") {
        return String::new();
    }
    crate::vision::webcam::start_gesture_watch();
    crate::vision::webcam::take_pending_gesture()
}

/// Returns recent visual context entries from the vision store.
/// Used by proactive idle prompts to know what the user was doing before going idle.
pub fn aura_get_recent_visual_context(limit: usize) -> String {
    match TX.get() {
        None => String::new(),
        Some(tx) => {
            let (reply_tx, reply_rx) = std::sync::mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::GetRecentVisualContext {
                limit,
                reply: reply_tx,
            });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or_default()
        }
    }
}

pub fn aura_start_webcam_thread() {
    crate::vision::webcam::state::GESTURE_ONLY.store(false, std::sync::atomic::Ordering::Relaxed);
    crate::vision::start_webcam_thread();
}

pub fn aura_stop_webcam_thread() {
    crate::vision::stop_webcam_thread();
}

pub fn aura_get_latest_webcam_scene() -> String {
    crate::vision::store::get_latest_webcam_scene()
}
