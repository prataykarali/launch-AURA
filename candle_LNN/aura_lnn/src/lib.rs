// src/lib.rs — public API that Flutter can call

pub mod tool_dispatcher;
pub mod tools;
pub mod llm_engine;

/// Simple ping to test connection
pub fn ping() -> String {
    "AURA is alive 🌙".to_string()
}

/// Chat with AURA (placeholder — real LLM next)
pub fn chat(input: &str) -> String {
    let forced = tool_dispatcher::needs_tool(input);
    if let Some(_json) = forced {
        // tool detected
        format!("Tool needed for: {input}")
    } else {
        format!("AURA heard: {input} 🌙")
    }
}