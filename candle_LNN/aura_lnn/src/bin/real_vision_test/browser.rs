use std::path::Path;
use std::process::Command;

/// Open a real headless Chrome browser, navigate to a test page,
/// capture a screenshot, then run YOLO detection on it.
pub fn test_browser_vision() {
    let chrome = find_chrome();
    if chrome.is_none() {
        println!("    [SKIP] No Chrome/Chromium found.");
        return;
    }
    let chrome = chrome.unwrap();

    // Capture a screenshot of a real webpage using headless Chrome
    let screenshot_path = "/tmp/aura_browser_screenshot.png";
    println!("    Using Chrome: {}", chrome);
    println!("    Capturing screenshot of https://example.com ...");

    let result = Command::new(&chrome)
        .args([
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            "--screenshot=/tmp/aura_browser_screenshot.png",
            "--window-size=1280,720",
            "https://example.com",
        ])
        .output();

    match result {
        Ok(output) => {
            println!(
                "    Chrome exit code: {}",
                output.status.code().unwrap_or(-1)
            );
            if !output.stderr.is_empty() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                if !stderr.is_empty() && stderr.len() < 500 {
                    println!("    Chrome stderr: {}", stderr.trim());
                }
            }
        }
        Err(e) => {
            println!("    [FAIL] Could not run Chrome: {}", e);
            return;
        }
    }

    if Path::new(screenshot_path).exists() {
        let meta = std::fs::metadata(screenshot_path).unwrap();
        println!(
            "    Screenshot captured: {} ({} bytes)",
            screenshot_path,
            meta.len()
        );

        // Now try to run YOLO on the screenshot
        // The webcam pipeline uses v4l2, but YOLO inference can run on any image
        // We'll use the YOLO model directly via the detection module
        println!("    Running YOLO on screenshot...");
        match run_yolo_on_image(screenshot_path) {
            Ok(detections) => {
                if detections.is_empty() {
                    println!("    YOLO found 0 objects in the screenshot.");
                    println!("    (example.com is mostly text — YOLO detects objects, not text)");
                } else {
                    println!("    YOLO found {} objects:", detections.len());
                    for d in &detections {
                        println!("      - {} ({:.1}%)", d.0, d.1 * 100.0);
                    }
                }
            }
            Err(e) => {
                println!("    YOLO on screenshot failed: {}", e);
                println!("    (YOLO inference module expects v4l2 frames — screenshot path needs adapter)");
            }
        }
    } else {
        println!("    [FAIL] Screenshot was not created.");
    }

    // Also navigate to a page with objects (a shopping site has product images)
    println!("\n    Capturing a page with visual content (a shopping page)...");
    let screenshot2 = "/tmp/aura_browser_objects.png";
    let _ = Command::new(&chrome)
        .args([
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            &format!("--screenshot={}", screenshot2),
            "--window-size=1280,720",
            "https://www.amazon.com",
        ])
        .output();

    if Path::new(screenshot2).exists() {
        let meta = std::fs::metadata(screenshot2).unwrap();
        println!("    Shopping page screenshot: {} bytes", meta.len());
    }
}

fn find_chrome() -> Option<String> {
    let candidates = [
        "/home/pratay-karali/.cache/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome",
        "/home/pratay-karali/.cache/puppeteer/chrome/linux-131.0.6778.204/chrome-linux64/chrome",
        "/usr/bin/chromium-browser",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium",
    ];
    for c in &candidates {
        if Path::new(c).exists() {
            return Some(c.to_string());
        }
    }
    None
}

fn run_yolo_on_image(_path: &str) -> Result<Vec<(String, f32)>, String> {
    // The YOLO detection module (src/vision/webcam/detection.rs) loads the ONNX
    // model and runs inference. It expects an RGB frame from the webcam adapter.
    // To run on a screenshot, we'd need to load the PNG, decode it, resize to 640x640,
    // and call infer_detections(). The detection module is pub(crate) so we can't
    // call it directly from here — but we can verify the model is loaded.
    //
    // For now, we report that the screenshot was captured but YOLO inference
    // on arbitrary images requires an adapter (the webcam module only reads from /dev/video0).
    Err("YOLO inference on screenshots requires an image-loading adapter (detection.rs is pub(crate)). Screenshot was captured successfully.".into())
}
