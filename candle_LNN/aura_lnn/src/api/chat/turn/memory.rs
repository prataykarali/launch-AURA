use crate::api::chat::output::cap_memory_item;
use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;
use crate::memory::{begin_memory_turn, should_inject_memory_item};

const RETRIEVAL_LIMIT: usize = 8;
const MEMORY_CHARS: usize = 180;

pub(crate) fn gather_memories(
    engine: &mut LlamaEngine,
    store: &MemoryStore,
    clean_prompt: &str,
) -> (Vec<String>, Option<Vec<f32>>) {
    let mut memories: Vec<String> = Vec::new();
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    begin_memory_turn();

    let mut query_embedding: Option<Vec<f32>> = None;
    if let Ok(qemb) = engine.embed_query(clean_prompt) {
        query_embedding = Some(qemb);
    }

    // Structured facts first — identity/preferences always available
    if let Ok(facts) = store.get_facts_strings(10) {
        for f in facts {
            let key = f.to_lowercase();
            if seen.insert(key) && should_inject_memory_item(&f) {
                memories.push(cap_memory_item(&f, MEMORY_CHARS));
            }
        }
    }

    // Recent turns for conversation continuity
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            let key = t.to_lowercase();
            if seen.insert(key) && should_inject_memory_item(&t) {
                memories.push(cap_memory_item(&t, MEMORY_CHARS));
            }
        }
    }

    // Semantic RAG: cosine cutoff >= 0.45 in search_relevant_hybrid.
    // Returns nothing for irrelevant prompts so casual chat gets no spam.
    if let Some(ref qemb) = query_embedding {
        if let Ok(semantic) = store.search_relevant_hybrid(clean_prompt, qemb, RETRIEVAL_LIMIT) {
            for s in semantic {
                let key = s.to_lowercase();
                if seen.insert(key) && should_inject_memory_item(&s) {
                    memories.push(cap_memory_item(&s, MEMORY_CHARS));
                }
            }
        }
    }

    (memories, query_embedding)
}
