// src/plugins/screen_ocr.rs — Screen OCR plugin for AURA.
//
// Intercepts "what's on my screen" queries, captures the screen,
// runs tesseract OCR, and returns extracted text. Bypasses the
// resource guard for user-initiated captures.
//
// This is the P0 fix from aura_deep_dive_analysis.md:
// "Screen OCR Does Not Work (Severity 5/5)"
//
// ponytail: minimal plugin that does one thing — reads the screen
// when the user asks. No YOLO, no emotion, no pose. Just text.

use super::{Plugin, PluginContext, PluginError, PluginResult};
use std::process::Command;

/// Patterns that trigger screen OCR.
const SCREEN_TRIGGERS: &[&str] = &[
    "what's on my screen",
    "what is on my screen",
    "read my screen",
    "read the screen",
    "what does my screen say",
    "what's showing on my screen",
    "can you see my screen",
    "look at my screen",
    "screenshot",
    "what am i looking at",
    "what's in front of me",
    "read this",
    "read what's on screen",
    "screen text",
    "OCR",
];

pub struct ScreenOcrPlugin {
    available: bool,
}

impl ScreenOcrPlugin {
    pub fn new() -> Self {
        Self { available: false }
    }

    /// Check if tesseract is installed.
    fn check_tesseract(&self) -> bool {
        Command::new("tesseract")
            .arg("--version")
            .output()
            .is_ok()
    }

    /// Capture screen and run OCR. Returns extracted text.
    fn capture_and_read(&self) -> Result<String, PluginError> {
        // Step 1: Capture screen to temp file
        let tmp_path = "/tmp/aura_screen_capture.png";

        // Try grim (Wayland), then scrot (X11), then import (ImageMagick)
        let captured = Command::new("grim")
            .arg(tmp_path)
            .output()
            .or_else(|_| {
                Command::new("scrot")
                    .args(["-o", tmp_path])
                    .output()
            })
            .or_else(|_| {
                Command::new("import")
                    .args(["-window", "root", tmp_path])
                    .output()
            });

        match captured {
            Ok(output) if output.status.success() => {}
            Ok(output) => {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(PluginError::Handle(format!("Screen capture failed: {stderr}")));
            }
            Err(e) => {
                return Err(PluginError::Handle(format!("No screen capture tool found: {e}")));
            }
        }

        // Step 2: Run tesseract OCR
        let output = Command::new("tesseract")
            .args([tmp_path, "stdout", "--psm", "6"])  // psm 6 = uniform block of text
            .output()
            .map_err(|e| PluginError::Handle(format!("Tesseract failed: {e}")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(PluginError::Handle(format!("Tesseract error: {stderr}")));
        }

        let text = String::from_utf8_lossy(&output.stdout).trim().to_string();

        if text.is_empty() {
            return Err(PluginError::Handle("Screen capture succeeded but no text was found. The screen might be an image or have no readable text.".to_string()));
        }

        // Step 3: Truncate to reasonable length (AURA responses are short)
        let truncated = if text.len() > 500 {
            format!("{}...", &text[..500])
        } else {
            text
        };

        Ok(truncated)
    }

    /// Check if a prompt is asking about the screen.
    fn is_screen_query(&self, prompt: &str) -> bool {
        let lower = prompt.to_lowercase();
        SCREEN_TRIGGERS.iter().any(|t| lower.contains(t))
    }
}

impl Plugin for ScreenOcrPlugin {
    fn name(&self) -> &str {
        "screen_ocr"
    }

    fn priority(&self) -> i32 {
        75  // Standard priority, checked before LLM
    }

    fn init(&mut self, _ctx: &PluginContext) -> PluginResult<()> {
        self.available = self.check_tesseract();
        if self.available {
            eprintln!("[PLUGIN] screen_ocr: tesseract available, plugin enabled");
        } else {
            eprintln!("[PLUGIN] screen_ocr: tesseract not found, plugin disabled");
            eprintln!("[PLUGIN] screen_ocr: install with: sudo apt install tesseract-ocr");
        }
        Ok(())
    }

    fn can_handle(&self, prompt: &str, _ctx: &PluginContext) -> bool {
        self.available && self.is_screen_query(prompt)
    }

    fn handle(&self, _prompt: &str, _ctx: &PluginContext) -> PluginResult<Option<String>> {
        match self.capture_and_read() {
            Ok(text) => {
                // Format as AURA-style response
                let response = format!("here's what I see on your screen:\n\n{}", text);
                Ok(Some(response))
            }
            Err(PluginError::Handle(msg)) => {
                // Graceful fallback — let the LLM handle it
                eprintln!("[PLUGIN] screen_ocr: {msg}");
                Ok(None)
            }
            Err(e) => Err(e),
        }
    }

    fn post_process(&self, response: &str, _ctx: &PluginContext) -> String {
        // No post-processing needed
        response.to_string()
    }
}
