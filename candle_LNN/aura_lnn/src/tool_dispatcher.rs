use crate::tools::datetime::{DateTimeTool, DateTimeArgs};
use rig::tool::Tool;
use candle_core::Device;

pub fn parse_tool_call(output: &str) 
    -> Option<(String, serde_json::Value)> 
{
    let trimmed=output.trim();
    if !trimmed.starts_with('{'){ return None; }
    let v: serde_json::Value=serde_json::from_str(trimmed).ok()?;
    let tool_name=v.get("tool")?.as_str()?.to_string();
    let args=v.get("args")?.clone();
    Some((tool_name, args))
}

pub fn needs_tool(input: &str) -> Option<String> {
    let lower = input.to_lowercase();
    let words: Vec<&str> = lower.split_whitespace().collect();
    
    // must have a question signal
    let is_question = lower.ends_with('?')
        || words.first().map(|w| matches!(*w, 
            "what" | "whats" | "what's" | "tell" | 
            "show" | "give" | "get" | "current" | "check"
        )).unwrap_or(false);
    
    // time-specific phrases — NOT single words
    let time_phrases = [
        "what time", "what's the time", "whats the time",
        "current time", "time is it", "time now",
        "what date", "today's date", "todays date", 
        "current date", "what day", "what's today",
    ];
    
    let has_time_phrase = time_phrases
        .iter()
        .any(|phrase| lower.contains(phrase));
    
    // require BOTH a question signal AND a time phrase
    // "night time" → no question signal → no tool
    // "its night time" → no question signal → no tool  
    // "what time is it" → question + phrase → tool ✓
    // "current time" → question signal (first word) + phrase → tool ✓
    if is_question && has_time_phrase {
        return Some(r#"{"tool":"get_time","args":{}}"#.to_string());
    }
    
    None
}
pub async fn run_tool(name: &str, args: serde_json::Value) -> String {
    match name {
        "get_time" => {
            let tool = crate::tools::datetime::DateTimeTool;
            let parsed: crate::tools::datetime::DateTimeArgs = 
                serde_json::from_value(args)
                .unwrap_or(crate::tools::datetime::DateTimeArgs { 
                    format: None 
                });
            match rig::tool::Tool::call(&tool, parsed).await {
                Ok(out) => out.datetime,
                Err(e)  => format!("error: {e}"),
            }
        }
        _ => format!("unknown tool: {name}"),
    }
}

pub fn get_device() -> candle_core::Result<Device> {
    #[cfg(feature = "cuda")]
    {
        match Device::new_cuda(0) {
            Ok(d) => {
                println!("🚀 Using CUDA GPU");
                return Ok(d);
            }
            Err(e) => {
                println!("⚠️  CUDA failed: {e} — falling back to CPU");
            }
        }
    }
    println!("💻 Using CPU");
    Ok(Device::Cpu)
}

pub async fn dispatch(user_input: &str) -> Option<String> {
    let input_lower = user_input.to_lowercase();

    // datetime tool
    if input_lower.contains("time") 
    || input_lower.contains("date") {
        let tool = DateTimeTool;
        let args = DateTimeArgs { format: None };
        match tool.call(args).await {
            Ok(out) => return Some(format!("It's {} ✨", out.datetime)),
            Err(e)  => return Some(format!("Tool error: {}", e)),
        }
    }

    // no tool matched — return None, let LLM handle it
    None
}