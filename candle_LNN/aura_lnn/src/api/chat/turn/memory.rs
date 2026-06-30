use crate::api::chat::output::cap_memory_item;
use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;
use crate::memory::{begin_memory_turn, should_inject_memory_item};

/// Fixed retrieval budget. The embedder's cosine threshold (>= 0.70 in
/// `search_relevant_hybrid`) is the SOLE relevance gate. No facts table,
/// no keyword rules — the embedder finds relevant conversation turns and
/// facts naturally via cosine similarity over vec_memory.
const RETRIEVAL_LIMIT: usize = 8;
const MEMORY_CHARS: usize = 180;

pub(crate) fn gather_memories(
    engine: &mut LlamaEngine,
    store: &MemoryStore,
    clean_prompt: &str,
) -> (Vec<String>, Option<Vec<f32>>) {
    let mut memories: Vec<String> = Vec::new();
    begin_memory_turn();

    // Embed the query — the embedder's job. Used for semantic retrieval here
    // and for persona few-shot retrieval by the caller.
    let mut query_embedding: Option<Vec<f32>> = None;
    let emb_start = std::time::Instant::now();
    if let Ok(qemb) = engine.embed_query(clean_prompt) {
        query_embedding = Some(qemb);
        eprintln!("[LLM] Query embedded in {:?}", emb_start.elapsed());
    }

    // ── Semantic RAG: embedder finds relevant memory over vec_memory ──────
    // vec_memory contains conversation turns ("User: X\nAURA: Y") and any
    // previously embedded content. The cosine cutoff (>= 0.70) returns
    // nothing for irrelevant prompts, so casual chat gets no hits — no
    // spam. Recall queries ("what's my name", "continue studying") match
    // their stored conversation turns naturally.
    let rag_start = std::time::Instant::now();
    if let Some(ref qemb) = query_embedding {
        if let Ok(semantic) = store.search_relevant_hybrid(clean_prompt, qemb, RETRIEVAL_LIMIT) {
            for s in semantic {
                if should_inject_memory_item(&s) {
                    memories.push(cap_memory_item(&s, MEMORY_CHARS));
                }
            }
        }
    }
    eprintln!(
        "[AURA_PERF] memory.semantic_search(limit={RETRIEVAL_LIMIT})={:?} -> {} hits",
        rag_start.elapsed(),
        memories.len()
    );

    (memories, query_embedding)
}
