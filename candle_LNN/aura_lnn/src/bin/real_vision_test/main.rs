use aura_lnn::memory::store::MemoryStore;
use aura_lnn::vision::events::{
    detections_to_semantic_event, semantic_event_to_memory_text, VisionEvent,
};
use aura_lnn::vision::gate::VisionGate;
use aura_lnn::vision::store::{get_recent_visual_context, store_visual_event};
use std::time::{Duration, Instant};

mod browser;
mod webcam;

fn main() {
    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    println!("================================================================");
    println!("  AURA REAL VISION TEST — Live Webcam + Browser Screenshot");
    println!("================================================================\n");

    let db = "temp_real_vision.db";
    let _ = std::fs::remove_file(db);
    let store = MemoryStore::open(db).unwrap();

    // ── Phase 1: Start webcam pipeline ───────────────────────────────
    println!("[1] Starting webcam pipeline (YOLOv8n + pose + FER+ emotion)...");
    let start = Instant::now();
    aura_lnn::vision::start_webcam_thread();
    println!("    Started in {:?}", start.elapsed());
    println!("    Waiting 10s for first detections (YOLO runs first in rotation)...\n");
    std::thread::sleep(Duration::from_secs(10));

    // ── Phase 2: Check YOLO detections ───────────────────────────────
    println!("[2] Live YOLO detections:");
    let dets = aura_lnn::vision::store::get_latest_webcam_detections();
    let scene = aura_lnn::vision::store::get_latest_webcam_scene();
    println!("    Scene: {}", scene);
    println!("    Objects: {}", dets.len());
    for d in &dets {
        println!("      -> {} ({:.0}%)", d.label, d.confidence * 100.0);
    }
    if dets.is_empty() {
        println!("    No detections yet. Waiting 10 more seconds...");
        std::thread::sleep(Duration::from_secs(10));
    }

    // ── Phase 3: Semantic event ──────────────────────────────────────
    println!("\n[3] Semantic understanding:");
    let dets = aura_lnn::vision::store::get_latest_webcam_detections();
    if !dets.is_empty() {
        let ev = detections_to_semantic_event(&dets);
        let mem = semantic_event_to_memory_text(&ev);
        println!("    Activity: {} / {}", ev.activity, ev.subactivity);
        println!("    Screen: {}", ev.screen);
        println!("    Objects: {:?}", ev.objects);
        println!(
            "    Importance: {} (conf: {:.2})",
            ev.importance, ev.confidence
        );
        println!("    Memory: {}", mem);
        let ve = VisionEvent::new(&dets, 0.6);
        store_visual_event(&store, &ve).unwrap();
        println!("    [STORED to memory DB]");
    } else {
        println!("    No detections to analyze.");
    }

    // ── Phase 4: VisionGate on real data ─────────────────────────────
    println!("\n[4] VisionGate (real data):");
    let mut gate = VisionGate::new(5, 0.45, 0.5);
    if let Some(ev) = gate.process_detections(dets.clone()) {
        println!("    PASSED: {}", ev.text);
    } else {
        println!("    BLOCKED (confidence/importance/dedup)");
    }
    // Wait for rotation to pose/emotion model
    println!("    Waiting 5s for model rotation (pose/emotion)...");
    std::thread::sleep(Duration::from_secs(5));
    let dets2 = aura_lnn::vision::store::get_latest_webcam_detections();
    if let Some(ev) = gate.process_detections(dets2.clone()) {
        println!("    Second pass: {}", ev.text);
    } else {
        println!("    Second pass: BLOCKED (same objects in cooldown)");
    }

    // ── Phase 5: Gesture detection ───────────────────────────────────
    println!("\n[5] Gesture detection (pose model):");
    let gesture = webcam::get_gesture();
    match gesture.as_deref() {
        Some(g) if !g.is_empty() => println!("    DETECTED: {}", g),
        _ => println!("    No gesture detected. (Wave at the camera to test!)"),
    }

    // ── Phase 6: Emotion detection ───────────────────────────────────
    println!("\n[6] Emotion detection (FER+):");
    let scene2 = webcam::get_scene();
    let emotions = [
        "smiling",
        "surprised",
        "tired",
        "sad",
        "focused",
        "strained",
    ];
    let found: Vec<&str> = emotions
        .iter()
        .filter(|e| scene2.to_lowercase().contains(*e))
        .copied()
        .collect();
    if !found.is_empty() {
        println!("    Emotions detected: {:?}", found);
        println!("    Scene: {}", scene2);
    } else {
        println!("    No emotion in scene yet. Scene: {}", scene2);
        println!("    (FER+ runs in rotation — face the camera and smile to test)");
    }

    // ── Phase 7: Retrieve stored memory ──────────────────────────────
    println!("\n[7] Visual memory retrieval:");
    let ctx = get_recent_visual_context(&store, 5).unwrap();
    println!("    {} entries stored:", ctx.len());
    for (i, c) in ctx.iter().enumerate() {
        println!("      {}: {}", i, c);
    }

    // ── Phase 8: Browser screenshot ──────────────────────────────────
    println!("\n[8] Browser screenshot test:");
    browser::test_browser_vision();

    // ── Phase 9: Can AURA answer "what do you see?" ──────────────────
    println!("\n[9] Can AURA answer 'what do you see?' with stored visual memory:");
    if !ctx.is_empty() {
        println!(
            "    Yes — AURA has {} visual memory entries to draw from.",
            ctx.len()
        );
        println!("    When user asks 'what do you see?', these are injected into the LLM:");
        for c in &ctx {
            println!("      >> {}", c);
        }
    } else {
        println!("    No visual memory stored — AURA cannot answer vision queries.");
    }

    // ── Cleanup ──────────────────────────────────────────────────────
    println!("\n[10] Stopping webcam...");
    aura_lnn::vision::stop_webcam_thread();
    std::thread::sleep(Duration::from_secs(1));
    drop(store);
    let _ = std::fs::remove_file(db);
    let _ = std::fs::remove_file(format!("{}-wal", db));
    let _ = std::fs::remove_file(format!("{}-shm", db));

    println!("\n================================================================");
    println!("  REAL VISION TEST COMPLETE");
    println!("================================================================");
}
