use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use aura_lnn::memory::store::MemoryStore;

pub fn start_memory_thread(store: MemoryStore, running: Arc<AtomicBool>) -> thread::JoinHandle<()> {
    thread::spawn(move || {
        let mut gate = aura_lnn::vision::VisionGate::new(30, 0.55, 0.5);
        while running.load(Ordering::Relaxed) {
            let detections = aura_lnn::vision::store::get_latest_webcam_detections();
            if let Some(event) = gate.process_detections(detections) {
                match aura_lnn::vision::store_visual_event(&store, &event) {
                    Ok(()) => eprintln!("[AURA_VISION] Stored visual event: {}", event.text),
                    Err(e) => eprintln!("[AURA_VISION] Failed to store visual event: {e:?}"),
                }
            }
            thread::sleep(Duration::from_secs(2));
        }
    })
}

pub fn print_latest_semantic_event() {
    let detections = aura_lnn::vision::store::get_latest_webcam_detections();
    if detections.is_empty() {
        println!("\n--- Latest Semantic Event ---");
        println!("No detected objects are available yet.");
        return;
    }

    let event = aura_lnn::vision::events::detections_to_semantic_event(&detections);
    match serde_json::to_string_pretty(&event) {
        Ok(json) => {
            println!("\n--- Latest Semantic Event ---");
            println!("{json}");
        }
        Err(e) => println!("Failed to format semantic event: {e:?}"),
    }
}
