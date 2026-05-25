use std::sync::atomic::{AtomicBool, Ordering};

pub struct AblationFlags {
    pub memory_enabled: AtomicBool,
    pub tools_enabled:  AtomicBool,
    pub cache_enabled:  AtomicBool,
}

impl AblationFlags {
    pub fn new() -> Self {
        Self {
            memory_enabled: AtomicBool::new(true),
            tools_enabled:  AtomicBool::new(true),
            cache_enabled:  AtomicBool::new(true),
        }
    }
    pub fn memory(&self) -> bool { self.memory_enabled.load(Ordering::Relaxed) }
    pub fn tools(&self)  -> bool { self.tools_enabled.load(Ordering::Relaxed) }
    pub fn cache(&self)  -> bool { self.cache_enabled.load(Ordering::Relaxed) }
}
