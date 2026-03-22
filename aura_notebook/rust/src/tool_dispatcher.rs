use crate::tools::datetime::{DateTimeTool, DateTimeArgs};
use rig::tool::Tool;

/// Parse model-generated tool JSON from output
/// Returns (tool_name, args) only if output is pure JSON
pub fn parse_tool_call(output: &str) -> Option<(String, serde_json::Value)> {
    let trimmed = output.trim();
    // Must start AND end with braces — reject mixed text like "JSON + extra words"
    if !trimmed.starts_with('{') || !trimmed.ends_with('}') {
        return None;
    }
    let v: serde_json::Value = serde_json::from_str(trimmed).ok()?;
    let tool_name = v.get("tool")?.as_str()?.to_string();
    let args = v.get("args")?.clone();
    Some((tool_name, args))
}

/// Keyword-based fast path — bypasses LLM entirely for obvious tool calls
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

    let has_time_phrase = time_phrases.iter().any(|p| lower.contains(p));

    if is_question && has_time_phrase {
        return Some(r#"{"tool":"get_time","args":{}}"#.to_string());
    }
    None
}

/// Execute a tool by name with given args
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

// ── Dead code suppressed — kept for future use ───────────────────────────────

#[allow(dead_code)]
pub fn get_device() -> candle_core::Result<candle_core::Device> {
    #[cfg(feature = "cuda")]
    {
        match candle_core::Device::new_cuda(0) {
            Ok(d) => { println!("🚀 Using CUDA GPU"); return Ok(d); }
            Err(e) => { println!("⚠️  CUDA failed: {e} — falling back to CPU"); }
        }
    }
    println!("💻 Using CPU");
    Ok(candle_core::Device::Cpu)
}

#[allow(dead_code)]
pub async fn dispatch(user_input: &str) -> Option<String> {
    let lower = user_input.to_lowercase();
    // Tight match — not loose contains("time")
    let triggers = ["what time", "current time", "what date", "current date", "what day"];
    if triggers.iter().any(|t| lower.contains(t)) {
        let tool = DateTimeTool;
        let args = DateTimeArgs { format: None };
        match tool.call(args).await {
            Ok(out) => return Some(format!("It's {} ✨", out.datetime)),
            Err(e)  => return Some(format!("Tool error: {}", e)),
        }
    }
    None
}