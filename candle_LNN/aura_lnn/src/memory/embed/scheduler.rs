// src/memory/embed/scheduler.rs - RL bandit scheduler (proactive trigger selection).
//
// Lives here for historical reasons — it just delegates to MemoryStore's
// epsilon-greedy policy.
// ──────────────────────────────────────────────────────────────────────────

use crate::memory::store::MemoryStore;

pub struct RLScheduler {}

impl Default for RLScheduler {
    fn default() -> Self {
        Self::new()
    }
}

impl RLScheduler {
    pub fn new() -> Self {
        RLScheduler {}
    }

    pub fn get_suggestion(&self, store: &MemoryStore) -> Option<(i64, String)> {
        store.get_proactive_suggestion().ok().flatten()
    }

    pub fn record_engagement(&self, store: &MemoryStore, trigger_id: i64, engaged: bool) {
        let _ = store.record_engagement(trigger_id, engaged);
    }
}
