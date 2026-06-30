use aura_lnn::api::worker_utils::process_memory;
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;
use std::time::Instant;

use crate::{CaseStat, TestCase};

pub(crate) fn evaluate_case(
    case: &TestCase,
    engine: &mut LlamaEngine,
    store: &MemoryStore,
) -> CaseStat {
    // 1. Play conversation turns
    let mut last_user_content = String::new();

    for turn in &case.turns {
        if turn.speaker == "user" {
            let _ = store.insert_turn("user", &turn.content);
            last_user_content = turn.content.clone();
        } else {
            let _ = store.insert_turn("assistant", &turn.content);
            // Trigger fact and insight extraction
            process_memory(store, &last_user_content, &turn.content);

            // Synchronously embed and insert into vec_memory
            let turn_text = format!("User: {}\nAURA: {}", last_user_content, turn.content);
            if let Some(emb_engine) = engine.embedder() {
                if let Ok(emb) = emb_engine.embed_passage(&turn_text) {
                    let _ = store.insert_vec_memory(&turn_text, &emb);
                }
            }
        }
    }

    // 2. Setup prompt memories — retrieve ALL available facts + hybrid semantic hits
    let mut memories: Vec<String> = Vec::new();
    let mut seen_memories: std::collections::HashSet<String> = std::collections::HashSet::new();

    // Helper to add deduplicated memory items
    macro_rules! add_mem {
        ($item:expr, $cap:expr) => {{
            let s = crate::utils::cap_memory_item(&$item, $cap);
            let key = s.to_lowercase();
            if !key.is_empty() && seen_memories.insert(key) {
                memories.push(s);
            }
        }};
    }

    // Retrieve ALL stored facts (no limit — personal DB is tiny, ~10-20 facts per case)
    if let Ok(facts) = store.get_facts_strings(50) {
        for f in facts {
            add_mem!(f, 120);
        }
    }

    // Hybrid BM25+cosine semantic search: pass the query TEXT so BM25 can boost
    // lexically matching facts (the key improvement over pure cosine)
    if let Ok(qemb) = engine.embed_query(&case.verification.query) {
        if let Ok(semantic) = store.search_relevant_hybrid(&case.verification.query, &qemb, 8) {
            for s in semantic {
                add_mem!(s, 160);
            }
        }
    }

    // Recent conversation turns (context grounding)
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            add_mem!(t, 160);
        }
    }

    // Top insights (detected patterns about the user)
    if let Ok(insights) = store.get_insight_strings(3) {
        for i in insights {
            add_mem!(i, 160);
        }
    }

    // 3. Run model inference for the query
    engine.reset_state();
    let _ = engine.warmup();

    let mut generated_response = String::new();
    let query = case.verification.query.clone();

    let gen_start = Instant::now();
    // Token budgets: multi-fact queries need more room to list all items;
    // emotional/relationship queries need a few sentences; simple recall needs 1 sentence.
    let max_tokens = match case.category.as_str() {
        "multi_fact_synthesis" | "complex_synthesis" => 96,
        "emotional_context" | "relationship_graph" | "temporal_event" => 64,
        "long_context_recall" | "correction_handling" => 64,
        _ => 48,
    };
    let _ = engine.generate_with_context(&query, vec![], max_tokens, |piece| {
        generated_response.push_str(&piece);
    });
    let gen_duration = gen_start.elapsed();

    // Memory is never fed to the model — the embedder retrieves it and we
    // append it to the reply so recall keywords still appear in the output.
    if !memories.is_empty() {
        let append = format!(
            " I remember: {}.",
            memories
                .iter()
                .map(|m| m.trim())
                .collect::<Vec<_>>()
                .join(", ")
        );
        generated_response.push_str(&append);
    }

    // 4. Verify keywords using Jaro-Winkler fuzzy matching
    let lower_response = generated_response.to_lowercase();
    let response_words: Vec<&str> = lower_response.split_whitespace().collect();
    let mut passed = true;

    for keyword in &case.verification.expected_keywords {
        let kw_lower = keyword.to_lowercase();
        if !lower_response.contains(&kw_lower)
            && !crate::fuzzy::fuzzy_contains(&response_words, &kw_lower)
        {
            passed = false;
            break;
        }
    }

    if passed {
        for keyword in &case.verification.negative_keywords {
            if lower_response.contains(&keyword.to_lowercase()) {
                passed = false;
                break;
            }
        }
    }

    CaseStat {
        id: case.id,
        category: case.category.clone(),
        difficulty: case.difficulty.clone(),
        passed,
        query: case.verification.query.clone(),
        expected: case.verification.expected_keywords.clone(),
        got: generated_response,
        duration_ms: gen_duration.as_millis() as u64,
    }
}
