mod memory;

use crate::memory::store::MemoryStore;

/// Post-turn memory processing. No hardcoded extractors — the conversation
/// turn is stored in vec_memory by the caller via store_embed. The embedder
/// retrieves it naturally via cosine similarity when the user references a
/// past topic.
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
