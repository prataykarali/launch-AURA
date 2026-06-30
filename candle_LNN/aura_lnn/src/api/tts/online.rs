use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicI64, Ordering};

static ONLINE_TTS_BACKOFF_UNTIL_MS: AtomicI64 = AtomicI64::new(0);

fn epoch_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn url_encode(input: &str) -> String {
    let mut out = String::new();
    for b in input.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            b' ' => out.push('+'),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn try_piper_http_tts(text: &str) -> Option<String> {
    let endpoint = std::env::var("AURA_ONLINE_TTS_URL")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())?;

    let tmp_path = "/tmp/aura_online_tts.wav";
    let _ = std::fs::remove_file(tmp_path);

    let mut child = match Command::new("curl")
        .args([
            "--fail",
            "--silent",
            "--show-error",
            "--max-time",
            "4",
            "-X",
            "POST",
            "-H",
            "Content-Type: text/plain",
            "--data-binary",
            "@-",
            "-o",
            tmp_path,
            &endpoint,
        ])
        .stdin(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(e) => {
            eprintln!("[AURA_TTS] Piper HTTP TTS spawn failed: {e}");
            return None;
        }
    };

    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(text.as_bytes());
    }

    match child.wait_with_output() {
        Ok(output) => {
            let output_exists = Path::new(tmp_path).exists();
            let output_len = std::fs::metadata(tmp_path).map(|m| m.len()).unwrap_or(0);
            if output.status.success() && output_exists && output_len > 0 {
                eprintln!("[AURA_TTS] Piper HTTP TTS succeeded via {endpoint}");
                Some(tmp_path.to_string())
            } else {
                let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
                eprintln!(
                    "[AURA_TTS] Piper HTTP TTS failed: status={}, output_exists={output_exists}, output_bytes={output_len}, stderr={stderr}",
                    output.status
                );
                None
            }
        }
        Err(e) => {
            eprintln!("[AURA_TTS] Piper HTTP TTS wait failed: {e}");
            None
        }
    }
}

fn try_google_translate_tts(text: &str) -> Option<String> {
    let tmp_path = "/tmp/aura_google_tts.mp3";
    let _ = std::fs::remove_file(tmp_path);
    let text = if text.chars().count() > 180 {
        text.chars().take(180).collect::<String>()
    } else {
        text.to_string()
    };
    let url = format!(
        "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q={}",
        url_encode(&text)
    );
    let output = match Command::new("curl")
        .args([
            "--fail",
            "--silent",
            "--show-error",
            "--max-time",
            "4",
            "-A",
            "Mozilla/5.0",
            "-o",
            tmp_path,
            &url,
        ])
        .output()
    {
        Ok(output) => output,
        Err(e) => {
            eprintln!("[AURA_TTS] Google Translate TTS spawn failed: {e}");
            return None;
        }
    };

    let output_exists = Path::new(tmp_path).exists();
    let output_len = std::fs::metadata(tmp_path).map(|m| m.len()).unwrap_or(0);
    if output.status.success() && output_exists && output_len > 0 {
        eprintln!("[AURA_TTS] Google Translate TTS succeeded.");
        Some(tmp_path.to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        eprintln!(
            "[AURA_TTS] Google Translate TTS failed: status={}, output_exists={output_exists}, output_bytes={output_len}, stderr={stderr}",
            output.status
        );
        None
    }
}

pub(super) fn try_online_tts(text: &str) -> Option<String> {
    if std::env::var("AURA_DISABLE_ONLINE_TTS").ok().as_deref() == Some("1") {
        return None;
    }

    let now = epoch_millis();
    let backoff_until = ONLINE_TTS_BACKOFF_UNTIL_MS.load(Ordering::Relaxed);
    if now < backoff_until {
        eprintln!(
            "[AURA_TTS] Skipping online TTS during backoff ({}s remaining).",
            (backoff_until - now) / 1000
        );
        return None;
    }

    if let Some(path) = try_piper_http_tts(text) {
        return Some(path);
    }

    if let Some(path) = try_google_translate_tts(text) {
        return Some(path);
    }

    // All online sources failed. Back off for 30 minutes so the voice
    // stays consistent (offline) instead of flipping back and forth every
    // time the network hiccups.
    ONLINE_TTS_BACKOFF_UNTIL_MS.store(epoch_millis() + 30 * 60 * 1000, Ordering::Relaxed);
    eprintln!("[AURA_TTS] All online TTS sources failed; backing off 30 min");
    None
}
