use crate::memory::store::MemoryStore;
use crate::vision::events::VisionEvent;
use crate::vision::VisionDetection;
use anyhow::Result;

pub fn store_visual_event(store: &MemoryStore, event: &VisionEvent) -> Result<()> {
    // Vision is an observation stream, not a user-profile fact. Keep it in the
    // notebook/vec-memory lane so it can be recalled without polluting Profile.
    store.insert_memory_note("Vision", &event.text, false, false, None)?;
    Ok(())
}

pub fn get_recent_visual_context(store: &MemoryStore, limit: usize) -> Result<Vec<String>> {
    let conn = store.acquire_conn()?;
    let mut stmt = conn.prepare(
        "SELECT content FROM memory_notes
         WHERE deleted = 0 AND content LIKE 'vision:%'
         ORDER BY timestamp DESC LIMIT ?",
    )?;
    let rows = stmt.query_map([limit as i64], |row| row.get::<_, String>(0))?;
    let mut results = Vec::new();
    for res in rows {
        results.push(res?);
    }
    Ok(results)
}

use once_cell::sync::Lazy;
use std::sync::Mutex;

pub static LATEST_WEBCAM_SCENE: Lazy<Mutex<String>> = Lazy::new(|| {
    Mutex::new(
        "No visual scene summary available yet. Real-time camera feed is starting up.".to_string(),
    )
});

pub static LATEST_WEBCAM_DETECTIONS: Lazy<Mutex<Vec<VisionDetection>>> =
    Lazy::new(|| Mutex::new(Vec::new()));

pub fn get_latest_webcam_scene() -> String {
    LATEST_WEBCAM_SCENE.lock().unwrap().clone()
}

pub fn set_latest_webcam_scene(summary: String) {
    *LATEST_WEBCAM_SCENE.lock().unwrap() = summary;
}

pub fn get_latest_webcam_detections() -> Vec<VisionDetection> {
    LATEST_WEBCAM_DETECTIONS.lock().unwrap().clone()
}

pub fn set_latest_webcam_detections(detections: Vec<VisionDetection>) {
    *LATEST_WEBCAM_DETECTIONS.lock().unwrap() = detections;
}

pub fn complete_vision_workflow() -> &'static str {
    r#"Complete Vision Workflow

CAMERA / SCREEN / ANDROID ACCESSIBILITY
  -> Capture Manager
     Sources: camera, screen capture, Android Accessibility API
     Output: raw image
  -> OpenCV Pipeline
     Resize, crop, blur/denoise, motion detect, normalize, brightness correct
     Output: frame ready. OpenCV prepares pixels; it does not understand them.
  -> Parallel Vision Sensors
     OCR: screenshots -> visible text, filenames, errors, line numbers
     YOLO: frames -> objects such as laptop, monitor, coffee mug, phone
     MediaPipe: frames -> pose, hands, attention, typing/sitting/movement cues
  -> Vision Interpreter
     Tiny VLM/rule interpreter merges OCR + objects + pose into meaning.
     Example: User is debugging Python code while drinking coffee.
  -> Semantic Event Builder
     Example:
     {
       "activity": "coding",
       "subactivity": "debugging",
       "screen": "VS Code",
       "text": "SyntaxError",
       "objects": ["coffee", "laptop"],
       "importance": "medium",
       "confidence": 0.93
     }
  -> Visual Memory Store
     Store compact semantic events, not raw images:
     12:42 User debugging Python.
     12:48 Compilation successful.
     13:03 Switched to Chrome.
  -> Decision Engine
     Retrieve visual memory plus audio/context events before answering.
  -> Main LLM (AURA)

Event-driven optimization:
30 FPS camera -> OpenCV motion detection -> skip unchanged frames.
Only run OCR / YOLO / MediaPipe when motion or screen changes matter.

Full perception stack:
Sensors -> Vision / Audio / Context -> Event Normalization -> Memory Storage
-> Decision Engine -> Main LLM -> AURA Response"#
}
