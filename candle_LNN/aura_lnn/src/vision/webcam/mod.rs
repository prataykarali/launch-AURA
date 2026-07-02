#[cfg(target_os = "linux")]
pub mod capture;
#[cfg(target_os = "linux")]
pub mod detection;
#[cfg(target_os = "linux")]
pub mod draw;
#[cfg(target_os = "linux")]
pub mod emotion;
#[cfg(target_os = "linux")]
pub mod model;
#[cfg(target_os = "linux")]
pub mod pose;
#[cfg(target_os = "linux")]
pub mod state;
#[cfg(target_os = "linux")]
pub mod thread;

#[cfg(target_os = "linux")]
pub use state::{
    start_gesture_watch, start_webcam_thread, stop_webcam_thread, take_pending_gesture,
};

#[cfg(not(target_os = "linux"))]
pub fn start_webcam_thread() {
    eprintln!("[VISION] Webcam only supported on Linux.");
}

#[cfg(not(target_os = "linux"))]
pub fn start_gesture_watch() {
    eprintln!("[VISION] Gesture watch only supported on Linux.");
}

#[cfg(not(target_os = "linux"))]
pub fn stop_webcam_thread() {
    eprintln!("[VISION] Webcam only supported on Linux.");
}

#[cfg(not(target_os = "linux"))]
pub fn take_pending_gesture() -> String {
    String::new()
}
