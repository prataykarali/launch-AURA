use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Arc;

use crate::api::chat::persona_retrieval::match_memory_recall;
use crate::api::worker_utils::process_memory_with_schedule_embedding;
use crate::config::constants::THINKING_SENTINEL;
use crate::frb_generated::StreamSink;
use crate::llama_engine::{LlamaEngine, CANCEL_FLAG};
use crate::memory::store::MemoryStore;
use crate::memory::{extract_schedule_note_hint, plan_reply};

mod classify;
mod generate;
mod memory;

/// Timestamp (epoch seconds) of the last conversation turn. If the gap
/// since the last turn exceeds NEW_CHAT_GAP_SECS, we recall what the last
/// conversation was about — once, not every turn.
static LAST_TURN_TS: AtomicI64 = AtomicI64::new(0);
const NEW_CHAT_GAP_SECS: i64 = 300; // 5 minutes

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

    if let Some(store) = memory_store {
        if !is_internal {
            let store_user_start = std::time::Instant::now();
            let _ = store.insert_turn("user", &clean_prompt);
            eprintln!(
                "[AURA_PERF] memory.insert_user_turn={:?}",
                store_user_start.elapsed()
            );
        }
    }

    let class = classify::classify(&clean_prompt, is_internal);
    if class.is_vision_query {
        crate::vision::start_webcam_thread();
    }

    // No prebuilt/canonical replies — every prompt goes through the LLM.

    let perf = engine.performance_profile();

    let mut memories: Vec<String> = Vec::new();
    let mut query_embedding: Option<Vec<f32>> = None;

    if let Some(store) = memory_store {
        let (mem, qemb) = memory::gather_memories(engine, store.as_ref(), &clean_prompt);
        memories = mem;
        query_embedding = qemb;
    }

    // ── Memory-recall fast path ───────────────────────────────────────────
    // If the query matches a memory_recall persona case (via embedder cosine),
    // DON'T run the LLM at all. Just output a short reply + the retrieved
    // memory. This skips the 17s prompt decode entirely for recall queries.
    if !is_internal && !is_bar {
        if let Some(ref qemb) = query_embedding {
            if let Some(_response_template) = match_memory_recall(qemb, 0.65) {
                // The query is a memory-recall query. Build the reply from
                // retrieved memory only — no LLM needed.
                let mut reply = String::new();
                if let Some(tail) = format_memory_appendage(&memories) {
                    reply = format!("Yes, I remember you.{}", tail);
                } else {
                    reply = "I don't know much about you yet. Tell me about yourself and I'll remember.".to_string();
                }
                let _ = sink.add(reply.clone());
                if let Some(store) = memory_store {
                    let _ = store.insert_turn("assistant", &reply);
                    engine.store_embed(
                        format!("User: {}\nAURA: {}", clean_prompt, reply),
                        Arc::clone(store),
                    );
                }
                #[cfg(target_os = "android")]
                log::info!("[AURA_WORKER] Memory-recall fast path for {clean_prompt:?}");
                drop(sink);
                return;
            }
        }
    }

    // Memory is NEVER fed into the LLM. The embedder's cosine cutoff is the
    // only relevance gate. KV cache resets are handled by the watermark inside
    // generate_with_context.

    if class.is_vision_query {
        if let Some(store) = memory_store {
            let vision_start = std::time::Instant::now();
            if let Ok(visual_events) = crate::vision::get_recent_visual_context(store, 3) {
                for ev in visual_events {
                    memories.insert(0, ev);
                }
            }
            eprintln!(
                "[AURA_PERF] memory.visual_context={:?}",
                vision_start.elapsed()
            );
        }
    }

    let fallback_memories = memories.clone();

    let generation_prompt = if is_bar {
        format!(
            "[Internal: The user said: \"{}\". Reply to THAT message as AURA — warm, brief, natural.]\n\n{}",
            clean_prompt, clean_prompt
        )
    } else {
        clean_prompt.clone()
    };

    let plan_start = std::time::Instant::now();
    let plan = plan_reply(
        &clean_prompt,
        cfg!(any(target_os = "android", target_os = "ios")),
    );
    eprintln!(
        "[AURA_PERF] plan_reply={:?} category={} level={} max_tokens={} continuation={} total_ceiling={} affect={} anchor=({:.2},{:.2})",
        plan_start.elapsed(),
        plan.category,
        plan.level,
        plan.max_tokens,
        plan.continuation,
        plan.total_ceiling(),
        plan.affect,
        plan.anchor_x,
        plan.anchor_y
    );
    let planned_tokens = if is_bar {
        plan.max_tokens.min(220)
    } else {
        plan.max_tokens
    };
    let max_tokens = perf.clamp_reply_tokens(planned_tokens);

    let mut sink = sink;
    let gen_start = std::time::Instant::now();
    let mut full_response = match generate::run_generation(
        engine,
        &generation_prompt,
        vec![], // NO persona examples — just system prompt + user message
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
    };
    eprintln!("[AURA_PERF] generation={:?}", gen_start.elapsed());

    // ── Last-conversation recall ──────────────────────────────────────────
    // If this is a new chat (gap > 5 min since last turn) and NOT internal,
    // recall what the last conversation was about. Fires ONCE per new-chat
    // gap. Uses the most recent vec_memory turn (not summary) for a natural
    // "I remember we talked about X" — not a wall of text.
    if !is_internal {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
        let last = LAST_TURN_TS.load(Ordering::Relaxed);
        // Only fire if there was a PREVIOUS turn (last != 0) AND the gap
        // exceeds the threshold. This prevents the very first turn ever
        // from triggering a recall (there's nothing to recall yet).
        let is_new_chat = last != 0 && (now - last) > NEW_CHAT_GAP_SECS;

        if is_new_chat {
            if let Some(store) = memory_store {
                // Get the most recent conversation turn from vec_memory
                if let Ok(turns) = store.recent_turn_strings_filtered(1) {
                    if let Some(turn) = turns.first() {
                        // Extract the user's message from "User: ...\nAURA: ..."
                        let lower = turn.to_lowercase();
                        let user_msg = if lower.starts_with("user:") {
                            let after = turn[5..].trim();
                            if let Some(idx) = after.to_lowercase().find("\naura:") {
                                after[..idx].trim()
                            } else {
                                after
                            }
                        } else {
                            turn.trim()
                        };
                        if !user_msg.is_empty() {
                            let short: String = user_msg.chars().take(80).collect();
                            let short = short.trim();
                            let is_trivial = short.split_whitespace().count() <= 4;
                            if !is_trivial {
                                let tail = format!(" I remember we were talking about {}.", short);
                                let _ = sink.add(tail.clone());
                                full_response.push_str(&tail);
                                #[cfg(target_os = "android")]
                                log::info!("[AURA_WORKER] Last-conversation recall for new chat");
                            }
                        }
                    }
                }
            }
        }
        LAST_TURN_TS.store(now, Ordering::Relaxed);
    }

    // ── Embedder retrieval APPENDED to the LLM reply ──────────────────────
    // Never fed into the model. Only fires when the embedder found something
    // semantically relevant (cosine >= 0.70). Casual chat gets no tail.
    // Works in both bar and chat app.
    if !is_internal {
        if let Some(tail) = format_memory_appendage(&memories) {
            let _ = sink.add(tail.clone());
            full_response.push_str(&tail);
        }
    }

    if let Some(store) = memory_store {
        if !is_internal {
            let post_store_start = std::time::Instant::now();
            let _ = store.insert_turn("assistant", &full_response);
            let schedule_embedding = extract_schedule_note_hint(&clean_prompt)
                .and_then(|note| engine.embedder().and_then(|e| e.embed_passage(&note).ok()));
            let new_facts = process_memory_with_schedule_embedding(
                store,
                &clean_prompt,
                &full_response,
                schedule_embedding.as_deref(),
            );
            for fact in new_facts {
                engine.store_embed(fact, Arc::clone(store));
            }

            engine.store_embed(
                format!("User: {}\nAURA: {}", clean_prompt, full_response),
                Arc::clone(store),
            );

            eprintln!(
                "[AURA_PERF] memory.post_response={:?}",
                post_store_start.elapsed()
            );
        }
    }

    eprintln!(
        "[AURA_WORKER] Total chat processing took {:?}",
        start_total.elapsed()
    );
    drop(sink);
}

/// Build the memory tail that is APPENDED to the LLM reply.
///
/// The embedder already decided what is relevant (cosine cutoff in
/// `search_relevant_hybrid`). We take ONLY the top 1 hit — no spam. If it's
/// a conversation turn ("User: ...\nAURA: ..."), extract the user's part.
/// Returns `None` when the embedder found nothing, so casual chat gets no tail.
pub(crate) fn format_memory_appendage(memories: &[String]) -> Option<String> {
    // Take only the TOP 1 — the most semantically relevant hit. No spam.
    let hit = memories.first()?;

    // Extract the user's message from a "User: ...\nAURA: ..." turn.
    let lower = hit.to_lowercase();
    let content = if lower.starts_with("user:") {
        let after_user = hit[5..].trim();
        if let Some(aura_idx) = after_user.to_lowercase().find("\naura:") {
            after_user[..aura_idx].trim()
        } else {
            after_user
        }
    } else if lower.starts_with("summary:") {
        hit[8..].trim()
    } else {
        hit.trim()
    };

    if content.is_empty() {
        return None;
    }

    // Don't append memory in a different script than the current conversation.
    let has_latin = content.chars().any(|c| c.is_ascii_alphabetic());
    let has_non_latin = content.chars().any(|c| c.is_alphabetic() && !c.is_ascii());
    if !has_latin && has_non_latin {
        return None;
    }

    // Convert first-person → second-person so "I remember: you like ice cream"
    // reads correctly (the stored turn has "I like ice cream" from the user's
    // perspective — AURA should say "you" not "I").
    let content = convert_first_to_second_person(content);

    Some(format!(" I remember: {}.", content))
}

/// Convert first-person pronouns to second-person so memory recall reads
/// naturally from AURA's perspective: "you like" not "I like".
fn convert_first_to_second_person(text: &str) -> String {
    let mut result = text.to_string();
    result = result.replace("i'm ", "you're ");
    result = result.replace("I'm ", "you're ");
    result = result.replace("i am ", "you are ");
    result = result.replace("I am ", "you are ");
    result = result.replace("my ", "your ");
    result = result.replace("My ", "your ");
    result = result.replace("mine", "yours");
    result = result.replace("myself", "yourself");
    // Replace standalone "i" → "you", but NOT inside words like "ice" or "like".
    result = replace_standalone_word(&result, "i", "you");
    result = replace_standalone_word(&result, "I", "you");
    result = replace_standalone_word(&result, "me", "you");
    result
}

/// Replace a standalone word (bounded by non-alphanumeric chars) with a
/// replacement. Handles ASCII text correctly — won't touch substrings.
fn replace_standalone_word(text: &str, word: &str, replacement: &str) -> String {
    let word_bytes = word.as_bytes();
    let repl_bytes = replacement.as_bytes();
    let bytes = text.as_bytes();
    let n = bytes.len();
    let wlen = word_bytes.len();
    let mut out = String::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + wlen <= n
            && &bytes[i..i + wlen] == word_bytes
            && (i == 0 || !bytes[i - 1].is_ascii_alphanumeric())
            && (i + wlen >= n || !bytes[i + wlen].is_ascii_alphanumeric())
        {
            out.push_str(std::str::from_utf8(repl_bytes).unwrap_or(replacement));
            i += wlen;
        } else {
            out.push(bytes[i] as char);
            i += 1;
        }
    }
    out
}

