use std::panic::AssertUnwindSafe;
use std::sync::atomic::Ordering;
use std::thread;
use std::time::{Duration, Instant};

use ort::session::Session;
use v4l::buffer::Type;
use v4l::io::traits::CaptureStream;
use v4l::prelude::*;

use crate::api::vision::aura_process_vision;
use crate::vision::events::VisionDetection;
use crate::vision::store::{set_latest_webcam_detections, set_latest_webcam_scene};
use crate::vision::webcam::capture::{
    calculate_frame_diff, open_device, run_gesture_only_loop, yuyv_to_rgb,
};
use crate::vision::webcam::detection::infer_detections;
use crate::vision::webcam::emotion::infer_expression_detections;
use crate::vision::webcam::model::{
    download_model_if_missing, get_emotion_path, get_pose_path, get_yolo_path,
    load_optional_session, EMOTION_URL, POSE_URL, YOLO_URL,
};
use crate::vision::webcam::pose::infer_pose_detections;
use crate::vision::webcam::state::{
    epoch_millis, GESTURE_FOR_DART, GESTURE_ONLY, GESTURE_PENDING, MOTION_STREAK, PREV_FRAME,
    RUNNING, WATCH_UNTIL_MS,
};
use crate::vision::webcam::vlm;

const INFERENCE_INTERVAL: Duration = Duration::from_millis(1200);

/// Model rotation phase: load ONE model at a time to avoid memory spikes.
/// Cycles YOLO → Pose → Emotion → VLM → YOLO → ...
#[derive(Clone, Copy, PartialEq)]
enum ModelPhase {
    Yolo,
    Pose,
    Emotion,
    Vlm,
}

pub fn spawn_webcam_loop() -> thread::JoinHandle<()> {
    thread::spawn(|| {
        if let Err(e) = run_webcam_loop() {
            eprintln!("[VISION] Webcam loop failed: {:?}", e);
            RUNNING.store(false, Ordering::Relaxed);
        }
    })
}

pub fn run_webcam_loop() -> anyhow::Result<()> {
    let gesture_only = GESTURE_ONLY.load(Ordering::Relaxed);

    // Headless gesture watch: skip the heavy ONNX models entirely —
    // only the camera + cheap frame-diff motion path.
    if gesture_only {
        return run_gesture_only_loop();
    }

    eprintln!("[VISION] Headless webcam loop (no display window).");
    eprintln!("[VISION] Loading models one-at-a-time (rotation mode).");

    // ── Load YOLO first (always needed for object detection) ───────────
    let yolo_path = get_yolo_path();
    download_model_if_missing(&yolo_path, YOLO_URL, 100_000, "YOLO object")?;
    eprintln!("[VISION] Loading YOLO model from {:?}", yolo_path);
    let mut yolo_session = Session::builder()
        .map_err(|e| anyhow::anyhow!("ort session builder: {e}"))?
        .with_intra_threads(1)
        .map_err(|e| anyhow::anyhow!("ort intra_threads: {e}"))?
        .commit_from_file(&yolo_path)
        .map_err(|e| anyhow::anyhow!("ort model load: {e}"))?;
    eprintln!("[VISION] YOLO model loaded.");

    // Pose + Emotion are loaded LAZILY on their rotation turn, then dropped.
    let mut pose_session: Option<Session> = None;
    let mut emotion_session: Option<Session> = None;
    let mut phase = ModelPhase::Yolo;

    eprintln!("[VISION] Opening webcam (headless)...");
    let (dev, cam_w, cam_h) = open_device()?;

    let mut stream = MmapStream::with_buffers(&dev, Type::VideoCapture, 4)
        .map_err(|e| anyhow::anyhow!("MmapStream: {e}"))?;

    // NO display window — AURA bar shows "watching" animation instead.
    let mut last_inference = Instant::now()
        .checked_sub(INFERENCE_INTERVAL)
        .unwrap_or_else(Instant::now);
    let mut latest_detections: Vec<VisionDetection> = Vec::new();

    eprintln!("[VISION] Entering headless camera + inference loop.");
    while RUNNING.load(Ordering::Relaxed)
        && epoch_millis() <= WATCH_UNTIL_MS.load(Ordering::Relaxed)
    {
        let (data, _meta) = match stream.next() {
            Ok(frame) => frame,
            Err(e) => {
                eprintln!("[VISION] Failed to capture frame: {:?}", e);
                thread::sleep(Duration::from_millis(100));
                continue;
            }
        };

        let rgb = yuyv_to_rgb(data, cam_w, cam_h);

        // Analyze motion for gesture detection
        if let Ok(mut prev_frame_lock) = PREV_FRAME.lock() {
            if let Some(ref prev_rgb) = *prev_frame_lock {
                if prev_rgb.len() == rgb.len() {
                    let diff = calculate_frame_diff(&rgb, prev_rgb, cam_w, cam_h);
                    let person_in_view = latest_detections
                        .iter()
                        .any(|d| d.label == "person" && d.confidence >= 0.45);
                    let gesture_threshold = if person_in_view { 7.5 } else { 14.0 };
                    let required_streak = if person_in_view { 2 } else { 4 };
                    if diff > gesture_threshold {
                        if let Ok(mut streak_lock) = MOTION_STREAK.lock() {
                            *streak_lock += 1;
                            if *streak_lock >= required_streak {
                                GESTURE_PENDING.store(true, Ordering::Relaxed);
                                *streak_lock = 0;
                            }
                        }
                    } else {
                        if let Ok(mut streak_lock) = MOTION_STREAK.lock() {
                            *streak_lock = 0;
                        }
                    }
                }
            }
            *prev_frame_lock = Some(rgb.clone());
        }

        if last_inference.elapsed() >= INFERENCE_INTERVAL {
            last_inference = Instant::now();

            // ── Model rotation: run ONE model per inference cycle ───────
            latest_detections.clear();

            match phase {
                ModelPhase::Yolo => {
                    match std::panic::catch_unwind(AssertUnwindSafe(|| {
                        infer_detections(&mut yolo_session, &rgb, cam_w, cam_h)
                    })) {
                        Ok(Ok(d)) => {
                            latest_detections = d;
                            eprintln!(
                                "[VISION] YOLO phase: {} detections",
                                latest_detections.len()
                            );
                        }
                        Ok(Err(e)) => eprintln!("[VISION] YOLO inference error: {:?}", e),
                        Err(_) => {
                            eprintln!("[VISION] YOLO inference PANIC — recovering");
                            thread::sleep(Duration::from_secs(2));
                        }
                    }
                    phase = ModelPhase::Pose;
                }
                ModelPhase::Pose => {
                    if pose_session.is_none() {
                        eprintln!("[VISION] Lazy-loading YOLO pose model...");
                        pose_session = load_optional_session(
                            "YOLO pose",
                            &get_pose_path(),
                            POSE_URL,
                            1_000_000,
                        );
                    }
                    if let Some(ref mut pose) = pose_session {
                        match std::panic::catch_unwind(AssertUnwindSafe(|| {
                            infer_pose_detections(pose, &rgb, cam_w, cam_h)
                        })) {
                            Ok(Ok(d)) => {
                                latest_detections = d;
                                eprintln!(
                                    "[VISION] Pose phase: {} detections",
                                    latest_detections.len()
                                );
                            }
                            Ok(Err(e)) => eprintln!("[VISION] Pose inference skipped: {:?}", e),
                            Err(_) => eprintln!("[VISION] Pose inference PANIC — recovering"),
                        }
                    }
                    pose_session = None;
                    eprintln!("[VISION] Dropped pose session (memory freed)");
                    phase = ModelPhase::Emotion;
                }
                ModelPhase::Emotion => {
                    if emotion_session.is_none() {
                        eprintln!("[VISION] Lazy-loading FER+ expression model...");
                        emotion_session = load_optional_session(
                            "FER+ expression",
                            &get_emotion_path(),
                            EMOTION_URL,
                            1_000_000,
                        );
                    }
                    if let Some(ref mut emotion) = emotion_session {
                        let quick_result = std::panic::catch_unwind(AssertUnwindSafe(|| {
                            infer_detections(&mut yolo_session, &rgb, cam_w, cam_h)
                        }));
                        if let Ok(Ok(quick_dets)) = quick_result {
                            match std::panic::catch_unwind(AssertUnwindSafe(|| {
                                infer_expression_detections(
                                    emotion,
                                    &rgb,
                                    cam_w,
                                    cam_h,
                                    &quick_dets,
                                )
                            })) {
                                Ok(Ok(d)) => {
                                    latest_detections = quick_dets;
                                    latest_detections.extend(d);
                                    eprintln!(
                                        "[VISION] Emotion phase: {} detections",
                                        latest_detections.len()
                                    );
                                }
                                Ok(Err(e)) => {
                                    eprintln!("[VISION] Expression inference skipped: {:?}", e)
                                }
                                Err(_) => {
                                    eprintln!("[VISION] Emotion inference PANIC — recovering")
                                }
                            }
                        }
                    }
                    emotion_session = None;
                    eprintln!("[VISION] Dropped emotion session (memory freed)");
                    phase = ModelPhase::Vlm;
                }
                ModelPhase::Vlm => {
                    // VLM: pass the raw RGB frame to the Liquid VLM for a
                    // natural-language scene description. Runs every 4th cycle.
                    match vlm::describe_scene(&rgb, cam_w as u32, cam_h as u32) {
                        Some(description) => {
                            eprintln!("[VLM] Scene: {}", description);
                            // Push as a detection so it gets stored in memory.
                            latest_detections.push(VisionDetection {
                                label: format!("vlm_scene: {}", description),
                                confidence: 0.90,
                                bbox: None,
                            });
                            // Also set as the primary scene description
                            // (replaces the YOLO text labels for proactive).
                            set_latest_webcam_scene(format!("VLM sees: {}", description));
                        }
                        None => {
                            eprintln!(
                                "[VLM] No description generated (model unavailable or error)"
                            );
                        }
                    }
                    phase = ModelPhase::Yolo;
                }
            }

            // Check if a gesture was detected since last inference
            if GESTURE_PENDING.swap(false, Ordering::Relaxed) {
                GESTURE_FOR_DART.store(true, Ordering::Relaxed);
                latest_detections.push(VisionDetection {
                    label: "user waving / hand gesture".to_string(),
                    confidence: 0.95,
                    bbox: None,
                });
                eprintln!("[VISION] Injected user waving / hand gesture into detections");
            }

            if latest_detections.len() > 12 {
                latest_detections.truncate(12);
            }
            if !latest_detections.is_empty() {
                aura_process_vision(latest_detections.clone());
            }
            set_latest_webcam_detections(latest_detections.clone());

            let summary = if latest_detections.is_empty() {
                "I don't see anything of note in the camera view right now.".to_string()
            } else {
                let mut items = Vec::new();
                for vd in &latest_detections {
                    items.push(format!(
                        "a {} ({:.0}% confidence)",
                        vd.label,
                        vd.confidence * 100.0
                    ));
                }
                format!("In the camera feed, I currently see: {}.", items.join(", "))
            };
            set_latest_webcam_scene(summary);
        }

        // ~15fps capture rate — no display window to update.
        thread::sleep(Duration::from_millis(66));
    }

    RUNNING.store(false, Ordering::Relaxed);
    eprintln!("[VISION] Exiting headless webcam loop.");
    Ok(())
}
