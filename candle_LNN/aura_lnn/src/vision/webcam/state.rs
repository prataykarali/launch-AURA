use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::Mutex;
use std::thread::JoinHandle;

use once_cell::sync::Lazy;

pub static RUNNING: AtomicBool = AtomicBool::new(false);
pub static WATCH_UNTIL_MS: AtomicI64 = AtomicI64::new(0);
pub static WEBCAM_THREAD: Lazy<Mutex<Option<JoinHandle<()>>>> = Lazy::new(|| Mutex::new(None));
pub static PREV_FRAME: Lazy<Mutex<Option<Vec<u8>>>> = Lazy::new(|| Mutex::new(None));
pub static MOTION_STREAK: Lazy<Mutex<usize>> = Lazy::new(|| Mutex::new(0));
pub static GESTURE_PENDING: AtomicBool = AtomicBool::new(false);
// Mirror of GESTURE_PENDING that stays set until Dart polls it via
// aura_get_webcam_gesture(), so a wave can trigger an immediate greeting
// even though the webcam runs entirely on the Rust side.
pub static GESTURE_FOR_DART: AtomicBool = AtomicBool::new(false);
// When true, the webcam loop runs HEADLESS (no display window, no heavy
// ONNX inference) — only cheap frame-diff motion detection for gestures.
// This lets AURA react to waves without popping up a vision window.
pub static GESTURE_ONLY: AtomicBool = AtomicBool::new(false);

pub const WATCH_SESSION_MS: i64 = 20_000;
// Headless gesture watch stays alive longer between polls (Dart polls
// ~every 10s and re-extends this, so the camera stays on for gestures).
pub const GESTURE_WATCH_SESSION_MS: i64 = 60_000;

pub fn epoch_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub fn start_webcam_thread() {
    let session_ms = if GESTURE_ONLY.load(Ordering::Relaxed) {
        GESTURE_WATCH_SESSION_MS
    } else {
        WATCH_SESSION_MS
    };
    WATCH_UNTIL_MS.store(epoch_millis() + session_ms, Ordering::Relaxed);
    if RUNNING.load(Ordering::Relaxed) {
        eprintln!("[VISION] Webcam watch session extended.");
        return;
    }
    RUNNING.store(true, Ordering::Relaxed);

    let handle = crate::vision::webcam::thread::spawn_webcam_loop();
    *WEBCAM_THREAD.lock().unwrap() = Some(handle);
}

/// Start (or extend) a HEADLESS gesture-watch session: the camera runs
/// only for cheap frame-diff motion detection, with no display window
/// and no ONNX inference. Safe to call repeatedly to keep the session
/// alive while Dart is polling for gestures.
pub fn start_gesture_watch() {
    GESTURE_ONLY.store(true, Ordering::Relaxed);
    start_webcam_thread();
}

pub fn stop_webcam_thread() {
    RUNNING.store(false, Ordering::Relaxed);
    WATCH_UNTIL_MS.store(0, Ordering::Relaxed);
    GESTURE_ONLY.store(false, Ordering::Relaxed);
    if let Some(handle) = WEBCAM_THREAD.lock().unwrap().take() {
        let _ = handle.join();
    }
}

/// Consume the pending-gesture flag set by the webcam loop. Returns
/// "wave" if a gesture was detected since the last call, else "".
pub fn take_pending_gesture() -> String {
    if GESTURE_FOR_DART.swap(false, Ordering::Relaxed) {
        "wave".to_string()
    } else {
        String::new()
    }
}
