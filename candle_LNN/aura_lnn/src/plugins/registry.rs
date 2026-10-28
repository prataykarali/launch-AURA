// src/plugins/registry.rs — Plugin registry and dispatch.
//
// The registry holds all registered plugins, sorted by priority.
// The worker loop calls `try_handle()` before the LLM and
// `post_process_all()` after the LLM.

use super::{Plugin, PluginContext};
use std::sync::Mutex;

/// Thread-safe plugin registry. Initialized once at engine startup.
pub struct PluginRegistry {
    plugins: Mutex<Vec<Box<dyn Plugin>>>,
}

impl PluginRegistry {
    pub fn new() -> Self {
        Self {
            plugins: Mutex::new(Vec::new()),
        }
    }

    /// Register a plugin. Plugins are sorted by priority after registration.
    pub fn register(&self, plugin: Box<dyn Plugin>) {
        let mut plugins = self.plugins.lock().unwrap_or_else(|e| e.into_inner());
        plugins.push(plugin);
        plugins.sort_by_key(|p| p.priority());
    }

    /// Initialize all registered plugins. Called once at engine startup.
    pub fn init_all(&self, ctx: &PluginContext) {
        let mut plugins = self.plugins.lock().unwrap_or_else(|e| e.into_inner());
        for plugin in plugins.iter_mut() {
            match plugin.init(ctx) {
                Ok(()) => {
                    eprintln!("[PLUGIN] {} initialized", plugin.name());
                }
                Err(e) => {
                    eprintln!("[PLUGIN] {} failed to init: {e}", plugin.name());
                }
            }
        }
    }

    /// Try to handle a user message with plugins. Returns Some(response)
    /// if a plugin handled it, None if the LLM should handle it.
    pub fn try_handle(&self, prompt: &str, ctx: &PluginContext) -> Option<String> {
        let plugins = self.plugins.lock().unwrap_or_else(|e| e.into_inner());
        for plugin in plugins.iter() {
            if plugin.can_handle(prompt, ctx) {
                match plugin.handle(prompt, ctx) {
                    Ok(Some(response)) => {
                        eprintln!("[PLUGIN] {} handled prompt", plugin.name());
                        return Some(response);
                    }
                    Ok(None) => {
                        // Plugin declined to handle, continue to next
                    }
                    Err(e) => {
                        eprintln!("[PLUGIN] {} error: {e}", plugin.name());
                    }
                }
            }
        }
        None
    }

    /// Post-process a response through all plugins. Runs on every turn,
    /// even if no plugin handled the initial prompt.
    pub fn post_process_all(&self, response: &str, ctx: &PluginContext) -> String {
        let plugins = self.plugins.lock().unwrap_or_else(|e| e.into_inner());
        let mut result = response.to_string();
        for plugin in plugins.iter() {
            result = plugin.post_process(&result, ctx);
        }
        result
    }

    /// Shutdown all plugins. Called on engine shutdown.
    pub fn shutdown_all(&self) {
        let mut plugins = self.plugins.lock().unwrap_or_else(|e| e.into_inner());
        for plugin in plugins.iter_mut() {
            plugin.shutdown();
            eprintln!("[PLUGIN] {} shut down", plugin.name());
        }
    }

    /// Number of registered plugins.
    pub fn count(&self) -> usize {
        self.plugins.lock().unwrap_or_else(|e| e.into_inner()).len()
    }
}

impl Default for PluginRegistry {
    fn default() -> Self {
        Self::new()
    }
}
