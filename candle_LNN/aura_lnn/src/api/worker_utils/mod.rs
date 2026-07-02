mod memory;
pub mod rules;

use crate::memory::store::MemoryStore;

/// Post-turn memory processing. Extracts structured facts using the
/// centralized rules engine, stores them in the facts table, derives
/// behavioral insights, and maintains a rolling conversation summary.
pub fn process_memory(store: &MemoryStore, prompt: &str, response: &str) -> Vec<String> {
    memory::process_memory_inner(store, prompt, response, None)
}

pub(crate) fn process_memory_with_schedule_embedding(
    store: &MemoryStore,
    prompt: &str,
    response: &str,
    schedule_embedding: Option<&[f32]>,
) -> Vec<String> {
    memory::process_memory_inner(store, prompt, response, schedule_embedding)
}
