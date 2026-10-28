// src/plugins/mod.rs — Plugin system for AURA.
//
// Plugins intercept user messages BEFORE the LLM and post-process responses
// AFTER the LLM. The core engine never changes; plugins register at init
// and the worker loop checks them on every turn.
//
// Architecture:
//   User → Plugin.can_handle() → Plugin.handle() → skip LLM
//   User → Plugin.can_handle() = false → LLM → Plugin.post_process() → response
//
// ponytail: this is the ONLY new module. Everything else is untouched.

mod context;
mod registry;
pub mod screen_ocr;

pub use context::{PluginConfig, PluginContext};
pub use registry::PluginRegistry;
pub use screen_ocr::ScreenOcrPlugin;

use std::fmt;

/// Result type for plugin operations.
pub type PluginResult<T> = Result<T, PluginError>;

/// Errors that plugins can return.
#[derive(Debug)]
pub enum PluginError {
    Init(String),
    Handle(String),
    Other(String),
}

impl fmt::Display for PluginError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PluginError::Init(msg) => write!(f, "plugin init error: {msg}"),
            PluginError::Handle(msg) => write!(f, "plugin handle error: {msg}"),
            PluginError::Other(msg) => write!(f, "plugin error: {msg}"),
        }
    }
}

impl std::error::Error for PluginError {}

/// The core plugin trait. Implement this to add a new capability to AURA.
///
/// Lifecycle:
///   1. `init()` — called once at engine startup
///   2. `can_handle()` — called on every user message
///   3. `handle()` — called if can_handle returns true
///   4. `post_process()` — called after LLM generates (always, even if handle was skipped)
///   5. `shutdown()` — called on engine shutdown
///
/// Return `Some(response)` from `handle()` to skip the LLM entirely.
/// Return `None` from `handle()` to let the LLM handle it (post_process still runs).
pub trait Plugin: Send + Sync {
    /// Unique identifier (e.g., "web_search", "mcp_tools", "rive_character").
    fn name(&self) -> &str;

    /// Priority order. Lower = checked first. Default plugins use 100.
    /// Use 0-50 for critical plugins (security, safety).
    /// Use 50-100 for standard plugins (web search, tools).
    /// Use 100+ for cosmetic plugins (animation, logging).
    fn priority(&self) -> i32 {
        100
    }

    /// Called once at engine startup. Use this to load models, connect to
    /// external services, etc. Return Ok(()) to enable the plugin.
    fn init(&mut self, ctx: &PluginContext) -> PluginResult<()>;

    /// Can this plugin handle this user message? Called on every turn.
    /// Return true if you want `handle()` to be called.
    fn can_handle(&self, prompt: &str, ctx: &PluginContext) -> bool;

    /// Handle the user message. Return Some(response) to skip the LLM,
    /// or None to let the LLM handle it.
    fn handle(&self, prompt: &str, ctx: &PluginContext) -> PluginResult<Option<String>>;

    /// Post-process the LLM response. Called on every turn, even if
    /// can_handle returned false. Default: no-op (return response unchanged).
    fn post_process(&self, response: &str, _ctx: &PluginContext) -> String {
        response.to_string()
    }

    /// Called on engine shutdown. Clean up resources.
    fn shutdown(&mut self) {}
}
