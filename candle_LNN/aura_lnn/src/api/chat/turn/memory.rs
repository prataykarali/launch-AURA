use crate::api::chat::output::cap_memory_item;
use crate::api::chat::turn::extract_user_from_turn;
use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;
use crate::memory::{begin_memory_turn, should_inject_memory_item};

const RETRIEVAL_LIMIT: usize = 4;
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

    let wants_notes = query_wants_notes(clean_prompt);

    // 0. Identity facts first so "who am I?" is never left to a flipped turn.
    if is_identity_ask(clean_prompt) {
        if let Ok(facts) = store.get_facts_strings(4) {
            for f in facts {
                push_memory(&mut memories, &mut seen, f);
            }
        }
    }

    // 1. Archipelago Dynamic Graph RAG:
    // Anchor node cosine search (firewall >= 0.62) + 1-2 hop edge traversal.
    if let Ok(graph_facts) =
        store.search_graph_rag(clean_prompt, query_embedding.as_deref(), RETRIEVAL_LIMIT)
    {
        for f in graph_facts {
            if !wants_notes && is_note_item(&f) {
                continue;
            }
            push_memory(&mut memories, &mut seen, f);
        }
    }

    // 2. Recent turns for conversational continuity — skip the live user turn
    // (already inserted before retrieval) so it is not echoed as "memory".
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            if is_current_user_turn(&t, clean_prompt) {
                continue;
            }
            if !wants_notes && is_note_item(&t) {
                continue;
            }
            push_memory(&mut memories, &mut seen, t);
        }
    }

    // 3. Fallback semantic memory if graph had no match and cosine is high
    if memories.is_empty() {
        if let Some(ref qemb) = query_embedding {
            if let Ok(semantic) =
                store.search_relevant_hybrid(clean_prompt, qemb, RETRIEVAL_LIMIT)
            {
                for s in semantic {
                    if !wants_notes && is_note_item(&s) {
                        continue;
                    }
                    push_memory(&mut memories, &mut seen, s);
                }
            }
        }
    }

    (memories, query_embedding)
}

fn push_memory(memories: &mut Vec<String>, seen: &mut std::collections::HashSet<String>, item: String) {
    let key = item.to_lowercase();
    if seen.insert(key) && should_inject_memory_item(&item) {
        memories.push(cap_memory_item(&item, MEMORY_CHARS));
    }
}

fn is_identity_ask(prompt: &str) -> bool {
    let q = prompt.to_ascii_lowercase();
    q.contains("my name")
        || q.contains("who am i")
        || q.contains("who i am")
        || q.contains("remember me")
        || q.contains("do you know my name")
        || q.contains("do you remember my name")
}

fn query_wants_notes(prompt: &str) -> bool {
    let q = prompt.to_ascii_lowercase();
    q.contains("note") || q.contains("notebook") || q.contains("my notes")
}

fn is_note_item(s: &str) -> bool {
    let l = s.to_ascii_lowercase();
    l.starts_with("note —")
        || l.starts_with("note -")
        || l.starts_with("note:")
        || l.starts_with("kind: note")
}

fn is_current_user_turn(turn: &str, clean_prompt: &str) -> bool {
    let lower = turn.to_ascii_lowercase();
    if !lower.starts_with("user:") {
        return false;
    }
    extract_user_from_turn(turn).eq_ignore_ascii_case(clean_prompt.trim())
}
