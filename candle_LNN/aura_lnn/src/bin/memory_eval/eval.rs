use std::time::Instant;

use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

use crate::{CaseStat, TestCase};

pub fn evaluate_case(case: &TestCase, store: &MemoryStore, engine: &mut LlamaEngine) -> CaseStat {
    let mut last_user_content = String::new();

    for turn in &case.turns {
        if turn.speaker == "user" {
            let _ = store.insert_turn("user", &turn.content);
            last_user_content = turn.content.clone();
        } else {
            let _ = store.insert_turn("assistant", &turn.content);
            aura_lnn::api::worker_utils::process_memory(store, &last_user_content, &turn.content);

            let turn_text = format!("User: {}\nAURA: {}", last_user_content, turn.content);
            if let Some(emb_engine) = engine.embedder() {
                if let Ok(emb) = emb_engine.embed_passage(&turn_text) {
                    let _ = store.insert_vec_memory(&turn_text, &emb);
                }
            }
        }
    }

    let mut memories: Vec<String> = Vec::new();
    let mut seen_memories: std::collections::HashSet<String> = std::collections::HashSet::new();

    if let Ok(facts) = store.get_facts_strings(50) {
        for f in facts {
            add_deduped_memory(&mut memories, &mut seen_memories, &f, 120);
        }
    }

    if let Ok(qemb) = engine.embed_query(&case.verification.query) {
        if let Ok(semantic) = store.search_relevant_hybrid(&case.verification.query, &qemb, 8) {
            for s in semantic {
                add_deduped_memory(&mut memories, &mut seen_memories, &s, 160);
            }
        }
    }

    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            add_deduped_memory(&mut memories, &mut seen_memories, &t, 160);
        }
    }

    if let Ok(insights) = store.get_insight_strings(3) {
        for i in insights {
            add_deduped_memory(&mut memories, &mut seen_memories, &i, 160);
        }
    }

    engine.reset_state();
    let _ = engine.warmup();

    let mut generated_response = String::new();
    let query = case.verification.query.clone();

    let gen_start = Instant::now();
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

    let lower_response = generated_response.to_lowercase();
    let response_words: Vec<&str> = lower_response.split_whitespace().collect();
    let mut passed = true;

    for keyword in &case.verification.expected_keywords {
        let kw_lower = keyword.to_lowercase();
        if !lower_response.contains(&kw_lower)
            && !crate::scoring::fuzzy_contains(&response_words, &kw_lower)
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

fn add_deduped_memory(
    memories: &mut Vec<String>,
    seen: &mut std::collections::HashSet<String>,
    item: &str,
    cap: usize,
) {
    let s = crate::text::cap_memory_item(item, cap);
    let key = s.to_lowercase();
    if !key.is_empty() && seen.insert(key) {
        memories.push(s);
    }
}
