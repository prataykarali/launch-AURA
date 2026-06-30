use std::thread;
use std::time::Duration;

use v4l::buffer::Type;
use v4l::format::Format;
use v4l::io::traits::CaptureStream;
use v4l::prelude::*;
use v4l::video::Capture;
use v4l::FourCC;

use crate::vision::webcam::state::{
    epoch_millis, GESTURE_FOR_DART, MOTION_STREAK, PREV_FRAME, RUNNING, WATCH_UNTIL_MS,
};

pub fn open_device() -> anyhow::Result<(Device, usize, usize)> {
    let dev = match Device::with_path("/dev/video0") {
        Ok(d) => d,
        Err(_e) => {
            eprintln!("[VISION] Failed to open /dev/video0, trying /dev/video1.");
            Device::with_path("/dev/video1")
                .map_err(|e| anyhow::anyhow!("No video capture device found: {e}"))?
        }
    };
    let req_fmt = Format::new(640, 480, FourCC::new(b"YUYV"));
    let fmt = dev
        .set_format(&req_fmt)
        .map_err(|e| anyhow::anyhow!("set_format: {e}"))?;
    eprintln!(
        "[VISION] Camera format set to {}x{} ({})",
        fmt.width, fmt.height, fmt.fourcc
    );
    let cam_w = fmt.width as usize;
    let cam_h = fmt.height as usize;
    Ok((dev, cam_w, cam_h))
}

pub fn open_gesture_device() -> anyhow::Result<(Device, usize, usize)> {
    let dev = match Device::with_path("/dev/video0") {
        Ok(d) => d,
        Err(_e) => {
            eprintln!("[VISION] (gesture) /dev/video0 unavailable, trying /dev/video1.");
            Device::with_path("/dev/video1")
                .map_err(|e| anyhow::anyhow!("No video capture device for gesture watch: {e}"))?
        }
    };
    let req_fmt = Format::new(320, 240, FourCC::new(b"YUYV"));
    let fmt = dev
        .set_format(&req_fmt)
        .map_err(|e| anyhow::anyhow!("set_format (gesture): {e}"))?;
    let cam_w = fmt.width as usize;
    let cam_h = fmt.height as usize;
    Ok((dev, cam_w, cam_h))
}

/// Headless, lightweight gesture watch: opens the camera, runs only cheap
/// frame-diff motion detection (no ONNX, no display window), and sets
/// GESTURE_FOR_DART whenever sustained motion (a wave/gesture) is seen.
/// Exits when the watch session expires or stop_webcam_thread() is called.
pub fn run_gesture_only_loop() -> anyhow::Result<()> {
    use std::sync::atomic::Ordering;
    eprintln!("[VISION] Starting headless gesture-watch loop.");
    let (dev, cam_w, cam_h) = open_gesture_device()?;
    let mut stream = MmapStream::with_buffers(&dev, Type::VideoCapture, 4)
        .map_err(|e| anyhow::anyhow!("MmapStream (gesture): {e}"))?;

    while RUNNING.load(Ordering::Relaxed)
        && epoch_millis() <= WATCH_UNTIL_MS.load(Ordering::Relaxed)
    {
        let (data, _meta) = match stream.next() {
            Ok(frame) => frame,
            Err(e) => {
                eprintln!("[VISION] (gesture) capture failed: {:?}", e);
                thread::sleep(Duration::from_millis(100));
                continue;
            }
        };
        let rgb = yuyv_to_rgb(data, cam_w, cam_h);

        if let Ok(mut prev_lock) = PREV_FRAME.lock() {
            if let Some(ref prev_rgb) = *prev_lock {
                if prev_rgb.len() == rgb.len() {
                    let diff = calculate_frame_diff(&rgb, prev_rgb, cam_w, cam_h);
                    // No person-detection in headless mode, so use the
                    // higher (no-person) motion threshold + streak.
                    let gesture_threshold = 14.0;
                    let required_streak = 3;
                    if diff > gesture_threshold {
                        if let Ok(mut streak_lock) = MOTION_STREAK.lock() {
                            *streak_lock += 1;
                            if *streak_lock >= required_streak {
                                GESTURE_FOR_DART.store(true, Ordering::Relaxed);
                                eprintln!(
                                    "[VISION] (gesture) motion streak → gesture flagged for Dart"
                                );
                                *streak_lock = 0;
                            }
                        }
                    } else if let Ok(mut streak_lock) = MOTION_STREAK.lock() {
                        *streak_lock = 0;
                    }
                }
            }
            *prev_lock = Some(rgb);
        }

        // ~10fps for the headless watcher — cheap on CPU.
        thread::sleep(Duration::from_millis(100));
    }
    eprintln!("[VISION] Headless gesture-watch loop exiting.");
    Ok(())
}

pub fn calculate_frame_diff(curr: &[u8], prev: &[u8], w: usize, h: usize) -> f32 {
    let mut diff_sum = 0.0f64;
    let mut count = 0;
    // Sample every 16th pixel to keep CPU usage near zero
    for y in (0..h).step_by(16) {
        for x in (0..w).step_by(16) {
            let idx = (y * w + x) * 3;
            if idx + 2 < curr.len() {
                let r_diff = (curr[idx] as i32 - prev[idx] as i32).abs();
                let g_diff = (curr[idx + 1] as i32 - prev[idx + 1] as i32).abs();
                let b_diff = (curr[idx + 2] as i32 - prev[idx + 2] as i32).abs();
                diff_sum += (r_diff + g_diff + b_diff) as f64 / 3.0;
                count += 1;
            }
        }
    }
    if count > 0 {
        (diff_sum / count as f64) as f32
    } else {
        0.0
    }
}

pub fn yuyv_to_rgb(yuyv: &[u8], w: usize, h: usize) -> Vec<u8> {
    let mut rgb = vec![0; w * h * 3];
    let num_pixels = w * h;
    for i in 0..(num_pixels / 2) {
        let yuyv_idx = i * 4;
        if yuyv_idx + 3 >= yuyv.len() {
            break;
        }
        let y0 = yuyv[yuyv_idx] as f32;
        let u = yuyv[yuyv_idx + 1] as f32;
        let y1 = yuyv[yuyv_idx + 2] as f32;
        let v = yuyv[yuyv_idx + 3] as f32;

        let u_offset = u - 128.0;
        let v_offset = v - 128.0;

        let r0 = (y0 + 1.402 * v_offset).clamp(0.0, 255.0) as u8;
        let g0 = (y0 - 0.344136 * u_offset - 0.714136 * v_offset).clamp(0.0, 255.0) as u8;
        let b0 = (y0 + 1.772 * u_offset).clamp(0.0, 255.0) as u8;

        let r1 = (y1 + 1.402 * v_offset).clamp(0.0, 255.0) as u8;
        let g1 = (y1 - 0.344136 * u_offset - 0.714136 * v_offset).clamp(0.0, 255.0) as u8;
        let b1 = (y1 + 1.772 * u_offset).clamp(0.0, 255.0) as u8;

        let rgb_idx0 = i * 6;
        rgb[rgb_idx0] = r0;
        rgb[rgb_idx0 + 1] = g0;
        rgb[rgb_idx0 + 2] = b0;

        rgb[rgb_idx0 + 3] = r1;
        rgb[rgb_idx0 + 4] = g1;
        rgb[rgb_idx0 + 5] = b1;
    }
    rgb
}

pub fn resize_rgb(src: &[u8], src_w: usize, src_h: usize, dst_w: usize, dst_h: usize) -> Vec<u8> {
    let mut dst = vec![0; dst_w * dst_h * 3];
    for y in 0..dst_h {
        let src_y = (y * src_h) / dst_h;
        for x in 0..dst_w {
            let src_x = (x * src_w) / dst_w;
            let src_idx = (src_y * src_w + src_x) * 3;
            let dst_idx = (y * dst_w + x) * 3;
            dst[dst_idx] = src[src_idx];
            dst[dst_idx + 1] = src[src_idx + 1];
            dst[dst_idx + 2] = src[src_idx + 2];
        }
    }
    dst
}
