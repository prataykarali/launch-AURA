use std::io::{self, Write};

use aura_lnn::api::{aura_tts_speak, worker_utils};
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

// Re-use the library's memory prefix builder (handles structured facts,
// skips assistant responses, converts to second person properly)
use aura_lnn::api::build_memory_prefix;

pub fn run_turn(engine: &mut LlamaEngine, store: &MemoryStore, prompt: &str, tts_enabled: bool) {
    if prompt.is_empty() {
        return;
    }

    println!("\nGenerating response...");

    // ── Retrieve memories ──────────────────────────────────────────────
    let mut memories = Vec::new();
    let mut seen = std::collections::HashSet::new();

    // 1. Structured facts (if any)
    if let Ok(facts) = store.get_facts_strings(10) {
        for f in &facts {
            let key = f.to_lowercase();
            if seen.insert(key) {
                memories.push(f.clone());
            }
        }
        if !facts.is_empty() {
            eprintln!("[EMBEDDER_DEBUG] Facts from DB: {:?}", facts);
        } else {
            eprintln!("[EMBEDDER_DEBUG] No structured facts in DB");
        }
    }

    // 2. Semantic search via embedder
    if let Ok(qemb) = engine.embed_query(prompt) {
        if let Ok(semantic) = store.search_relevant_hybrid(prompt, &qemb, 5) {
            eprintln!("[EMBEDDER_DEBUG] Hybrid search: {} results for '{prompt}'", semantic.len());
            for (i, s) in semantic.iter().enumerate() {
                let preview: String = s.chars().take(80).collect();
                eprintln!("[EMBEDDER_DEBUG]   hit[{i}]: {preview}...");
            }
            for s in semantic {
                let key = s.to_lowercase();
                if seen.insert(key) {
                    memories.push(s);
                }
            }
        }
    }

    // 3. Recent turns
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            let key = t.to_lowercase();
            if seen.insert(key) {
                memories.push(t);
            }
        }
    }

    eprintln!("[EMBEDDER_DEBUG] Total memories: {}", memories.len());

    // ── Build memory prefix for injection (Option 1) ───────────────────
    let memory_prefix = build_memory_prefix(&memories);
    if let Some(ref prefix) = memory_prefix {
        eprintln!("[MEMORY_INJECTION] {prefix}");
    } else {
        eprintln!("[MEMORY_INJECTION] No memory to inject");
    }

    engine.reset_state();
    let _ = engine.warmup();

    // ── Generate WITH memory injected into context ─────────────────────
    let full_prompt = match &memory_prefix {
        Some(prefix) => format!("{prefix}{prompt}"),
        None => prompt.to_string(),
    };

    let mut response = String::new();
    print!("AURA: ");
    io::stdout().flush().unwrap();

    let _ = engine.generate_with_context(&full_prompt, vec![], 64, |token| {
        print!("{token}");
        io::stdout().flush().unwrap();
        response.push_str(&token);
    });

    println!();

    // Store turn
    let _ = store.insert_turn("user", prompt);
    let _ = store.insert_turn("assistant", &response);

    // Process memory — extract facts, store them, return clean fact strings
    let new_facts = worker_utils::process_memory(store, prompt, &response);
    for fact in &new_facts {
        if let Ok(emb) = engine.embed_query(fact) {
            let _ = store.insert_vec_memory(fact, &emb);
        }
    }
    if new_facts.is_empty() {
        let user_msg = format!("User: {}", prompt);
        if let Ok(emb) = engine.embed_query(&user_msg) {
            let _ = store.insert_vec_memory(&user_msg, &emb);
        }
    }

    if tts_enabled && !response.trim().is_empty() {
        let _ = aura_tts_speak(response, 1.0, true);
    }
}
