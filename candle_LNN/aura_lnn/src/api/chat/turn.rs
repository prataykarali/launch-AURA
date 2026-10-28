use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;

// match_memory_recall removed — fast path disabled, always uses LLM
use crate::api::worker_utils::process_memory_with_schedule_embedding;
use crate::config::constants::THINKING_SENTINEL;
use crate::frb_generated::StreamSink;
use crate::llama_engine::{LlamaEngine, CANCEL_FLAG};
use crate::memory::store::MemoryStore;
use crate::memory::{extract_schedule_note_hint, plan_reply};

mod classify;
mod generate;
mod memory;
pub mod prefix;

static LAST_TURN_TS: AtomicI64 = AtomicI64::new(0);

pub(crate) fn process_chat(
    engine: &mut LlamaEngine,
    memory_store: &Option<Arc<MemoryStore>>,
    prompt: String,
    sink: StreamSink<String>,
    _cached_memories: Option<Vec<String>>,
) {
    let start_total = std::time::Instant::now();
    CANCEL_FLAG.store(false, Ordering::Relaxed);
    let _ = sink.add(THINKING_SENTINEL.to_string());
    let (is_internal, is_bar, clean_prompt) = classify::prepare_prompt(&prompt);

    // Ensure notes never leak into default chat RAG (explicit query only).
    // Skip the live user turn from retrieval so it is not treated as memory.
    if let Some(store) = memory_store {
        let _ = store.insert_turn("user", &clean_prompt);
    }

    if let Some(store) = memory_store {
        if !is_internal {
            let _ = store.insert_turn("user", &clean_prompt);
        }
    }

    let class = classify::classify(&clean_prompt, is_internal);
    if class.is_vision_query {
        crate::vision::start_webcam_thread();
    }

    let perf = engine.performance_profile();
    let mut memories: Vec<String> = Vec::new();

    if let Some(store) = memory_store {
        let (mem, _qemb) = memory::gather_memories(engine, store.as_ref(), &clean_prompt);
        memories = mem;
    }

    // Memory-recall fast path: disabled by design to always feed the main LLM.
    // Memory prefix injection [MEMORY: ...] already gives the LLM the facts it needs.

    if class.is_vision_query {
        if let Some(store) = memory_store {
            if let Ok(visual_events) = crate::vision::get_recent_visual_context(store, 3) {
                for ev in visual_events {
                    memories.insert(0, ev);
                }
            }
        }
    }

    let fallback_memories = memories.clone();

    // Build memory prefix for injection (Option 1)
    let memory_prefix = build_memory_prefix(&memories);
    if let Some(ref prefix) = memory_prefix {
        eprintln!("[MEMORY_INJECTION] Injecting {} chars", prefix.len());
    }

    // Build conversation recap so the model has multi-turn context even
    // after a KV-cache reset (the recurrent state is cleared at the watermark
    // and only the system prompt is re-warmed — without this recap, the model
    // forgets all prior conversation after ~15-20 turns).
    let conversation_recap = build_conversation_recap(&memories);

    let generation_prompt = if is_bar {
        format!(
            "{}{}[Internal: The user said: \"{}\". Reply to THAT message as ARIA — warm, brief, natural.]\n\n{}",
            memory_prefix.as_deref().unwrap_or(""),
            conversation_recap.as_deref().unwrap_or(""),
            clean_prompt, clean_prompt
        )
    } else {
        format!(
            "{}{}{}",
            memory_prefix.as_deref().unwrap_or(""),
            conversation_recap.as_deref().unwrap_or(""),
            clean_prompt
        )
    };

    let final_prompt = generation_prompt;

    let plan = plan_reply(
        &clean_prompt,
        cfg!(any(target_os = "android", target_os = "ios")),
    );
    let planned_tokens = if is_bar {
        plan.max_tokens.min(220)
    } else {
        plan.max_tokens
    };
    let max_tokens = perf.clamp_reply_tokens(planned_tokens);

    let mut sink = sink;
    let mut full_response = if let Some(grounded) =
        super::reply::grounded_identity_if_clear(&clean_prompt, &fallback_memories)
    {
        eprintln!("[AURA_WORKER] Grounded identity reply (skipped LLM)");
        let _ = sink.add(grounded.clone());
        grounded
    } else {
        match generate::run_generation(
            engine,
            &final_prompt,
            vec![],
            max_tokens,
            is_bar,
            &perf,
            &plan,
            &clean_prompt,
            &fallback_memories,
            &mut sink,
        ) {
            Ok(response) => response,
            Err(e) => {
                eprintln!("[AURA_WORKER_ERR] generate failed: {:?}", e);
                String::new()
            }
        }
    };

    // Last-conversation recall for new chat sessions disabled by design.
    if !is_internal {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
        LAST_TURN_TS.store(now, Ordering::Relaxed);
    }

    // Memory appendage is DISABLED — the [MEMORY:] prefix injection already
    // gives the LLM the facts it needs. The "I remember: ..." tail was
    // repetitive and confusing (always showed the same fact). The LLM now
    // naturally weaves facts into its response from the prefix injection.
    // if !is_internal { ... format_memory_appendage ... } — removed

    // Store turn and process memory
    if let Some(store) = memory_store {
        if !is_internal {
            let _ = store.insert_turn("assistant", &full_response);
            let schedule_embedding = extract_schedule_note_hint(&clean_prompt)
                .and_then(|note| engine.embedder().and_then(|e| e.embed_passage(&note).ok()));
            let new_facts = process_memory_with_schedule_embedding(
                store,
                &clean_prompt,
                &full_response,
                schedule_embedding.as_deref(),
            );
            // Store clean extracted facts as separate vectors (high priority)
            for fact in &new_facts {
                engine.store_embed(fact.clone(), Arc::clone(store));
            }
            // Store user-only message (not full turn) so embedder retrieves
            // clean user statements, not messy "User: X\nARIA: Y" turns
            if new_facts.is_empty() {
                engine.store_embed(format!("User: {}", clean_prompt), Arc::clone(store));
            }
        }
    }

    eprintln!("[AURA_WORKER] Total chat took {:?}", start_total.elapsed());
    drop(sink);
}

pub(crate) fn extract_user_from_turn(turn: &str) -> String {
    let lower = turn.to_lowercase();
    if !lower.starts_with("user:") {
        return turn.trim().to_string();
    }
    let after = turn[5..].trim();
    let after_lower = after.to_lowercase();
    let cut = ["\naria:", "\naura:", "\nassistant:"]
        .iter()
        .filter_map(|m| after_lower.find(m))
        .min();
    if let Some(idx) = cut {
        after[..idx].trim().to_string()
    } else {
        after.to_string()
    }
}

pub use prefix::build_conversation_recap;
pub use prefix::build_memory_prefix;
pub use prefix::build_recall_prefill;
