// sam_chat — single-message AURA CLI. Takes a message as arg,
// runs the full pipeline (memory, fact extraction, proactive check),
// prints the response. Also prints side effects (facts extracted,
// proactive triggers, emotion changes).
use aura_lnn::api::worker_utils::process_memory;
use aura_lnn::api::{build_memory_prefix, configure_rayon_threads};
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::plan_reply;
use aura_lnn::memory::store::MemoryStore;
use std::sync::Arc;

const DEFAULT_MODEL: &str = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
const DEFAULT_DB: &str = "/home/pratay-karali/.local/share/aura_notebook/aura_memory.db";

fn model_path() -> String {
    std::env::var("AURA_MODEL_PATH").unwrap_or_else(|_| DEFAULT_MODEL.to_string())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: sam_chat \"message\" [db_path]");
        return;
    }
    let msg = &args[1];
    let db = args
        .get(2)
        .cloned()
        .unwrap_or_else(|| DEFAULT_DB.to_string());
    let model = model_path();

    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    configure_rayon_threads();

    let embedder = LlamaEngine::load_sibling_embedder(&model).expect("embedder");
    let mut engine = LlamaEngine::new(
        &model,
        aura_lnn::device_backend::DeviceBackend::Cpu,
        2048,
        2,
        embedder,
    )
    .expect("engine");
    let store = Arc::new(MemoryStore::open(&db).expect("db"));

    // Gather memories (same as production with the fix)
    let mut memories = Vec::new();
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    if let Ok(facts) = store.get_facts_strings(10) {
        for f in facts {
            let k = f.to_lowercase();
            if seen.insert(k) {
                memories.push(f);
            }
        }
    }
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            let k = t.to_lowercase();
            if seen.insert(k) {
                memories.push(t);
            }
        }
    }
    if let Ok(qemb) = engine.embed_query(msg) {
        if let Ok(sem) = store.search_relevant_hybrid(msg, &qemb, 8) {
            for s in sem {
                let k = s.to_lowercase();
                if seen.insert(k) {
                    memories.push(s);
                }
            }
        }
    }

    // Check proactive BEFORE chat
    let proactive_before = store.get_proactive_suggestion().ok().flatten();

    // Build prefix + generate
    let prefix = build_memory_prefix(&memories);
    let prompt = if let Some(p) = &prefix {
        format!("{}{}", p, msg)
    } else {
        msg.clone()
    };
    let plan = plan_reply(msg, false);
    let max_tokens = engine
        .performance_profile()
        .clamp_reply_tokens(plan.max_tokens);

    store.insert_turn("user", msg).unwrap();
    engine.reset_state();
    let _ = engine.warmup();

    let mut response = String::new();
    let _ = engine.generate_with_context(&prompt, vec![], max_tokens, |t| response.push_str(&t));

    // Clean response
    let response = response.trim().to_string();
    println!("RESPONSE:{}", response);

    // Store + extract facts
    store.insert_turn("assistant", &response).unwrap();
    let new_facts = process_memory(&store, msg, &response);
    for f in &new_facts {
        if let Some(e) = engine.embedder() {
            if let Ok(emb) = e.embed_passage(f) {
                let _ = store.insert_vec_memory(f, &emb);
            }
        }
    }
    if new_facts.is_empty() {
        if let Some(e) = engine.embedder() {
            if let Ok(emb) = e.embed_passage(&format!("User: {}", msg)) {
                let _ = store.insert_vec_memory(&format!("User: {}", msg), &emb);
            }
        }
    }

    // Print side effects
    if !new_facts.is_empty() {
        println!("FACTS_EXTRACTED:{}", new_facts.join("|"));
    }

    // Check proactive AFTER chat
    let proactive_after = store.get_proactive_suggestion().ok().flatten();
    if let Some((id, label)) = &proactive_after {
        println!("PROACTIVE_FIRED:{}:{}", id, label);
        store.mark_trigger_fired(*id).unwrap();
    }

    // Print all stored facts
    if let Ok(facts) = store.get_facts_strings(50) {
        if !facts.is_empty() {
            println!("ALL_FACTS:{}", facts.join("|"));
        }
    }

    // Print bandit scores
    if let Ok(conn) = store.acquire_conn() {
        if let Ok(mut stmt) = conn
            .prepare("SELECT trigger_id, label, engagement_score, n_shown, n_engaged FROM triggers")
        {
            if let Ok(rows) = stmt.query_map([], |r| {
                Ok(format!(
                    "{}:{}:{:.2}:{}:{}",
                    r.get::<_, i64>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, f64>(2)?,
                    r.get::<_, i64>(3)?,
                    r.get::<_, i64>(4)?
                ))
            }) {
                let scores: Vec<String> = rows.filter_map(|r| r.ok()).collect();
                if !scores.is_empty() {
                    println!("BANDIT_SCORES:{}", scores.join(","));
                }
            }
        }
    }

    // Print proactive log
    if let Ok(logs) = store.recent_proactive_log(20) {
        if !logs.is_empty() {
            let entries: Vec<String> = logs
                .iter()
                .map(|l| {
                    format!(
                        "{}:{}:{}:{}",
                        l.trigger_id, l.trigger_type, l.engaged, l.timestamp
                    )
                })
                .collect();
            println!("PROACTIVE_LOG:{}", entries.join(","));
        }
    }
}
