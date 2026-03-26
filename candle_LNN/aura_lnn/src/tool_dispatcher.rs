use crate::tools::datetime::{DateTimeTool, DateTimeArgs};
use rig::tool::Tool;
use std::panic;

/// Parse model-generated tool JSON from output
pub fn parse_tool_call(output: &str) -> Option<(String, serde_json::Value)> {
    let trimmed = output.trim();
    if !trimmed.starts_with('{') || !trimmed.ends_with('}') {
        return None;
    }
    let v: serde_json::Value = serde_json::from_str(trimmed).ok()?;
    let tool_name = v.get("tool")?.as_str()?.to_string();
    let args = v.get("args")?.clone();
    Some((tool_name, args))
}

/// Keyword-based fast path — bypasses LLM for common queries
pub fn needs_tool(input: &str) -> Option<String> {
    let lower = input.to_lowercase();

    let is_question = lower.ends_with('?')
        || lower.split_whitespace().next().map(|w| matches!(w,
            "what" | "whats" | "what's" | "tell" | "show" |
            "give" | "get" | "current" | "check"
        )).unwrap_or(false);

    let time_phrases = [
        "what time", "what's the time", "whats the time",
        "current time", "time is it", "time now",
        "what date", "today's date", "todays date",
        "current date", "what day", "what's today",
    ];

    if is_question && time_phrases.iter().any(|p| lower.contains(p)) {
        return Some(r#"{"tool":"get_time","args":{}}"#.to_string());
    }
    None
}

/// The entry point called by Flutter
pub fn handle_tool_call_sync(raw: &str) -> String {
    // Wrap the WHOLE logic to prevent ANY panic from hitting the Android OS
    let result = panic::catch_unwind(|| {
        let mut results = Vec::new();

        // Use a proper JSON stream deserializer instead of manual index slicing
        let stream = serde_json::Deserializer::from_str(raw).into_iter::<serde_json::Value>();

        for value in stream {
            if let Ok(v) = value {
                if let (Some(name), Some(args)) = (v.get("tool").and_then(|n| n.as_str()), v.get("args")) {
                    results.push(run_tool_blocking(name, args.clone()));
                }
            }
        }

        if results.is_empty() { String::new() } else { results.join(" ") }
    });

    match result {
        Ok(output) => output,
        Err(_) => "CRITICAL_RUST_PANIC".to_string(),
    }
}

/// SAFE synchronous execution for Android NDK
fn run_tool_blocking(name: &str, args: serde_json::Value) -> String {
    // CRITICAL: catch_unwind stops the SIGABRT crash on Android
    let result = panic::catch_unwind(|| {
        match name {
            "get_time" => {
                // Utc is used to avoid missing timezone DB crashes on mobile
                let now = chrono::Utc::now(); 
                format!("It's {} UTC", now.format("%I:%M %p"))
            }
            _ => format!("unknown tool: {name}"),
        }
    });

    match result {
        Ok(output) => output,
        Err(_) => "Error: Rust tool panic caught".to_string(),
    }
}

/// Async execution for non-blocking UI tasks
pub async fn run_tool(name: &str, args: serde_json::Value) -> String {
    match name {
        "get_time" => {
            let tool = DateTimeTool;
            let parsed: DateTimeArgs = serde_json::from_value(args)
                .unwrap_or(DateTimeArgs { format: None });
            
            match Tool::call(&tool, parsed).await {
                Ok(out) => out.datetime,
                Err(e)  => format!("error: {e}"),
            }
        }
        _ => format!("unknown tool: {name}"),
    }
}

#[allow(dead_code)]
pub fn get_device() -> candle_core::Result<candle_core::Device> {
    #[cfg(feature = "cuda")]
    {
        if let Ok(d) = candle_core::Device::new_cuda(0) { return Ok(d); }
    }
    Ok(candle_core::Device::Cpu)
}