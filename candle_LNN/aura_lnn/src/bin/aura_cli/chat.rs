use std::io::{self, Write};

use aura_lnn::api::{aura_tts_speak, worker_utils};
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

pub fn run_turn(engine: &mut LlamaEngine, store: &MemoryStore, prompt: &str, tts_enabled: bool) {
    if prompt.is_empty() {
        return;
    }

    println!("\nGenerating response...");

    // Retrieve memories
    let mut memories = Vec::new();
    let mut seen = std::collections::HashSet::new();
    if let Ok(facts) = store.get_facts_strings(10) {
        for f in facts {
            let key = f.to_lowercase();
            if seen.insert(key) {
                memories.push(f);
            }
        }
    }
    if let Ok(qemb) = engine.embed_query(prompt) {
        if let Ok(semantic) = store.search_relevant_hybrid(prompt, &qemb, 5) {
            for s in semantic {
                let key = s.to_lowercase();
                if seen.insert(key) {
                    memories.push(s);
                }
            }
        }
    }
    if let Ok(recent) = store.recent_turn_strings_filtered(4) {
        for t in recent {
            let key = t.to_lowercase();
            if seen.insert(key) {
                memories.push(t);
            }
        }
    }

    // Direct identity recall bypass removed: memory is never fed to the LLM.
    // The embedder retrieves relevant memory and we append it to the reply.

    engine.reset_state();
    let _ = engine.warmup();

    let mut response = String::new();
    print!("AURA: ");
    io::stdout().flush().unwrap();

    let _ = engine.generate_with_context(prompt, vec![], 64, |token| {
        print!("{token}");
        io::stdout().flush().unwrap();
        response.push_str(&token);
    });

    // Append embedder-retrieved memory to the reply (never fed to the model).
    if !memories.is_empty() {
        let append = format!(
            " I remember: {}.",
            memories
                .iter()
                .map(|m| m.trim())
                .collect::<Vec<_>>()
                .join(", ")
        );
        print!("{append}");
        io::stdout().flush().unwrap();
        response.push_str(&append);
    }
    println!();

    // Store turn in memory DB
    let _ = store.insert_turn("user", prompt);
    let _ = store.insert_turn("assistant", &response);

    // Save vector memory
    let turn_text = format!("User: {prompt}\nAURA: {response}");
    if let Ok(emb) = engine.embed_query(&turn_text) {
        let _ = store.insert_vec_memory(&turn_text, &emb);
    }

    // Process memory to extract facts synchronously so the next prompt
    // can see them immediately.
    worker_utils::process_memory(store, prompt, &response);

    // Speak response using TTS
    if tts_enabled && !response.trim().is_empty() {
        let _ = aura_tts_speak(response, 1.0, true);
    }
}
