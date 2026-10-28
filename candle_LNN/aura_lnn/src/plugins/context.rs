// src/plugins/context.rs — Shared context passed to all plugins.
//
// Plugins receive this on every call. It gives them access to memory,
// the embedder, and configuration without needing direct references
// to the engine internals.

use std::sync::Arc;

use crate::memory::store::MemoryStore;
use crate::memory::Embedder;

/// Context passed to every plugin call. Plugins use this to:
/// - Read/write memory facts
/// - Embed queries for semantic search
/// - Access configuration
pub struct PluginContext {
    pub memory_store: Option<Arc<MemoryStore>>,
    pub embedder: Option<Arc<dyn Embedder + Send + Sync>>,
    pub config: PluginConfig,
}

/// Read-only configuration snapshot passed to plugins.
#[derive(Clone, Debug)]
pub struct PluginConfig {
    /// Platform: "linux", "android", "macos"
    pub platform: String,
    /// Whether the bar is active
    pub bar_active: bool,
    /// Current performance tier: "strong", "balanced", "constrained"
    pub perf_tier: String,
}

impl PluginConfig {
    pub fn detect() -> Self {
        let platform = if cfg!(target_os = "android") {
            "android".to_string()
        } else if cfg!(target_os = "macos") {
            "macos".to_string()
        } else {
            "linux".to_string()
        };
        Self {
            platform,
            bar_active: true,
            perf_tier: "balanced".to_string(),
        }
    }
}
