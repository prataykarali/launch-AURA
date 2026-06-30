use std::sync::atomic::Ordering;
use std::thread;
use std::time::{Duration, Instant};

use minifb::{Key, Window, WindowOptions};
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
use crate::vision::webcam::draw::{draw_rect, draw_rect_filled, draw_string};
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

const INFERENCE_INTERVAL: Duration = Duration::from_millis(900);

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

    // Headless gesture watch: skip the heavy ONNX models and the display
    // window entirely — only the camera + cheap frame-diff motion path.
    if gesture_only {
        return run_gesture_only_loop();
    }

    let yolo_path = get_yolo_path();
    download_model_if_missing(&yolo_path, YOLO_URL, 100_000, "YOLO object")?;

    eprintln!("[VISION] Loading YOLO model from {:?}", yolo_path);
    let mut session = Session::builder()
        .map_err(|e| anyhow::anyhow!("ort session builder: {e}"))?
        .with_intra_threads(1)
        .map_err(|e| anyhow::anyhow!("ort intra_threads: {e}"))?
        .commit_from_file(&yolo_path)
        .map_err(|e| anyhow::anyhow!("ort model load: {e}"))?;

    let mut pose_session =
        load_optional_session("YOLO pose", &get_pose_path(), POSE_URL, 1_000_000);
    let mut emotion_session = load_optional_session(
        "FER+ expression",
        &get_emotion_path(),
        EMOTION_URL,
        1_000_000,
    );

    eprintln!("[VISION] Opening webcam...");
    let (dev, cam_w, cam_h) = open_device()?;

    let mut stream = MmapStream::with_buffers(&dev, Type::VideoCapture, 4)
        .map_err(|e| anyhow::anyhow!("MmapStream: {e}"))?;

    eprintln!("[VISION] Creating display window...");
    let mut window = Window::new(
        "AURA Live Vision (YOLOv8)",
        cam_w,
        cam_h,
        WindowOptions::default(),
    )
    .map_err(|e| anyhow::anyhow!("Failed to create minifb window: {:?}", e))?;

    window.set_target_fps(30);

    let mut disp_buf = vec![0u32; cam_w * cam_h];
    let mut last_inference = Instant::now()
        .checked_sub(INFERENCE_INTERVAL)
        .unwrap_or_else(Instant::now);
    let mut latest_detections: Vec<VisionDetection> = Vec::new();

    eprintln!("[VISION] Entering camera capture and inference loop.");
    while RUNNING.load(Ordering::Relaxed)
        && epoch_millis() <= WATCH_UNTIL_MS.load(Ordering::Relaxed)
        && window.is_open()
        && !window.is_key_down(Key::Escape)
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
            latest_detections = infer_detections(&mut session, &rgb, cam_w, cam_h)?;

            if let Some(pose) = pose_session.as_mut() {
                match infer_pose_detections(pose, &rgb, cam_w, cam_h) {
                    Ok(mut pose_detections) => latest_detections.append(&mut pose_detections),
                    Err(e) => eprintln!("[VISION] Pose inference skipped: {:?}", e),
                }
            }

            if let Some(emotion) = emotion_session.as_mut() {
                match infer_expression_detections(emotion, &rgb, cam_w, cam_h, &latest_detections) {
                    Ok(mut expression_detections) => {
                        latest_detections.append(&mut expression_detections)
                    }
                    Err(e) => eprintln!("[VISION] Expression inference skipped: {:?}", e),
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

        // Update display buffer with camera pixels (YUYV to 0RGB)
        for i in 0..cam_w * cam_h {
            let r = rgb[i * 3] as u32;
            let g = rgb[i * 3 + 1] as u32;
            let b = rgb[i * 3 + 2] as u32;
            disp_buf[i] = (r << 16) | (g << 8) | b;
        }

        // Draw boxes and text labels
        for vd in &latest_detections {
            if let Some(bbox) = vd.bbox {
                let x1 = bbox[0] as i32;
                let y1 = bbox[1] as i32;
                let x2 = bbox[2] as i32;
                let y2 = bbox[3] as i32;

                let color = 0x00FF88;
                draw_rect(&mut disp_buf, cam_w, cam_h, x1, y1, x2, y2, 2, color);

                let label_text = format!("{}: {:.0}%", vd.label, vd.confidence * 100.0);
                let text_w = label_text.len() as i32 * 8;
                let ty = (y1 - 10).max(0);
                let tx = x1;
                draw_rect_filled(
                    &mut disp_buf,
                    cam_w,
                    cam_h,
                    tx,
                    ty,
                    tx + text_w,
                    ty + 10,
                    0x000000,
                );
                draw_string(&mut disp_buf, cam_w, cam_h, &label_text, tx, ty + 1, color);
            }
        }

        window
            .update_with_buffer(&disp_buf, cam_w, cam_h)
            .map_err(|e| anyhow::anyhow!("minifb update: {e}"))?;
    }

    RUNNING.store(false, Ordering::Relaxed);
    eprintln!("[VISION] Exiting webcam loop.");
    Ok(())
}
