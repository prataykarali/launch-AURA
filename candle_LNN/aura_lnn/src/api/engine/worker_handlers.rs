use std::sync::Arc;

use crate::api::chat::process_chat;
use crate::api::EngineMsg;
use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;
use crate::memory_health::{self, MemoryPressure};

pub(crate) fn dispatch_message(
    engine: &mut LlamaEngine,
    memory_store: &Option<Arc<MemoryStore>>,
    prefilled_memories: &mut Option<Vec<String>>,
    vision_gate: &mut crate::vision::VisionGate,
    msg: EngineMsg,
) {
    match msg {
        EngineMsg::Chat { prompt, sink } => {
            eprintln!("[AURA_WORKER] Chat request: {} chars", prompt.len());
            maybe_heal_memory_pressure(engine, memory_store, prefilled_memories);
            process_chat(
                engine,
                memory_store,
                prompt,
                sink,
                prefilled_memories.take(),
            );
        }
        EngineMsg::ChunkedChat { chunks, sink } => {
            let full_prompt = chunks.join("");
            eprintln!(
                "[AURA_WORKER] ChunkedChat request: {} chars",
                full_prompt.len()
            );
            maybe_heal_memory_pressure(engine, memory_store, prefilled_memories);
            process_chat(
                engine,
                memory_store,
                full_prompt,
                sink,
                prefilled_memories.take(),
            );
        }
        EngineMsg::ResetState => {
            engine.reset_state();
            *prefilled_memories = None;
        }
        EngineMsg::BufferStatus { reply } => {
            // Compute context-buffer metrics: turn count and token
            // estimate (char heuristic). Drift detection removed;
            // memory is only injected when the user explicitly
            // asks or relates to a stored topic, so old-topic
            // drift is prevented by architecture rather than
            // monitored after the fact.
            let turns = if let Some(ref store) = memory_store {
                store.turn_count().unwrap_or(0)
            } else {
                0
            };
            // ~4 tokens per 100 chars (Llama 2 1.2B tokenizer ratio).
            let tokens = (turns as i32) * 40;
            // Mechanical cap: signal when turns exceed the budget
            // and a summary/trim should fire.
            let intercept_needed = turns > 12;
            let message = if intercept_needed {
                "Context buffer full — summarizing older turns."
            } else {
                ""
            };
            let json = serde_json::json!({
                "intercept_needed": intercept_needed,
                "message": message,
                "turns": turns,
                "tokens": tokens,
            });
            let _ = reply.send(json.to_string());
        }
        EngineMsg::GetProactiveContext { reply } => {
            let ctx = if let Some(ref store) = memory_store {
                store.get_proactive_context().unwrap_or_default()
            } else {
                String::new()
            };
            let _ = reply.send(ctx);
        }
        EngineMsg::CheckScheduler { reply } => {
            let suggestion = if let Some(ref store) = memory_store {
                store
                    .get_proactive_suggestion()
                    .ok()
                    .flatten()
                    .map(|(id, label)| {
                        serde_json::json!({
                            "id": id,
                            "label": label,
                            "type": "bandit",
                        })
                        .to_string()
                    })
            } else {
                None
            };
            let _ = reply.send(suggestion);
        }
        EngineMsg::RecordEngagement {
            trigger_id,
            engaged,
            reply,
        } => {
            let ok = if let Some(ref store) = memory_store {
                store.record_engagement(trigger_id, engaged).is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::SearchRelevant {
            query,
            limit,
            reply,
        } => {
            let result =
                if let (Some(ref store), Some(embedder)) = (&memory_store, engine.embedder()) {
                    match embedder.embed_query(&query) {
                        Ok(qemb) => store
                            .search_relevant_hybrid(&query, &qemb, limit)
                            .map(|v| serde_json::to_string(&v).unwrap_or_else(|_| "[]".to_string()))
                            .unwrap_or_else(|_| "[]".to_string()),
                        Err(_) => "[]".to_string(),
                    }
                } else {
                    "[]".to_string()
                };
            let _ = reply.send(result);
        }
        EngineMsg::LogProactive {
            trigger_id,
            label,
            trigger_type,
            engaged,
            reply,
        } => {
            let ok = if let Some(ref store) = memory_store {
                if trigger_id > 0 && trigger_type == "bandit" && !engaged {
                    let _ = store.mark_trigger_fired(trigger_id);
                }
                store
                    .log_proactive(trigger_id, &label, &trigger_type, engaged)
                    .is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::AddMemoryNote {
            title,
            content,
            pinned,
            reply,
        } => {
            let id = if let (Some(ref store), Some(embedder)) = (&memory_store, engine.embedder()) {
                match embedder.embed_passage(&content) {
                    Ok(emb) => store
                        .insert_memory_note(&title, &content, pinned, false, Some(&emb))
                        .unwrap_or(-1),
                    Err(_) => -1,
                }
            } else {
                -1
            };
            let _ = reply.send(id);
        }
        EngineMsg::UpdateMemoryNote {
            id,
            title,
            content,
            pinned,
            deleted,
            reply,
        } => {
            let ok = if let Some(ref store) = memory_store {
                let embedding = if deleted {
                    None
                } else {
                    engine
                        .embedder()
                        .and_then(|embedder| embedder.embed_passage(&content).ok())
                };
                store
                    .update_memory_note(id, &title, &content, pinned, deleted, embedding.as_deref())
                    .is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::DeleteMemoryNote { id, reply } => {
            let ok = if let Some(ref store) = memory_store {
                store.delete_memory_note(id).is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::RecoverMemoryNote { id, reply } => {
            let ok = if let Some(ref store) = memory_store {
                let note_content = store.get_memory_notes().ok().and_then(|notes| {
                    notes
                        .into_iter()
                        .find(|note| note.id == id)
                        .map(|note| note.content)
                });
                let embedding = note_content.as_deref().and_then(|content| {
                    engine
                        .embedder()
                        .and_then(|embedder| embedder.embed_passage(content).ok())
                });
                store.recover_memory_note(id, embedding.as_deref()).is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::DeleteMemoryNotePermanently { id, reply } => {
            let ok = if let Some(ref store) = memory_store {
                store.delete_memory_note_permanently(id).is_ok()
            } else {
                false
            };
            let _ = reply.send(ok);
        }
        EngineMsg::ReadFileIntoMemory { path, label, reply } => {
            let ok = crate::api::file_read::handle_read_file_into_memory(
                engine,
                memory_store,
                &path,
                label,
            );
            let _ = reply.send(ok);
        }
        EngineMsg::VisionEvent { detections } => {
            // Always update the latest detections + scene summary so the
            // user sees something when they ask "what do you see", even
            // if the gate's cooldown suppresses the memory-store write.
            let summary = if detections.is_empty() {
                "I don't see anything of note in the camera view right now.".to_string()
            } else {
                let items: Vec<String> = detections
                    .iter()
                    .map(|d| format!("a {} ({:.0}% confidence)", d.label, d.confidence * 100.0))
                    .collect();
                format!("In the camera feed, I currently see: {}.", items.join(", "))
            };
            crate::vision::store::set_latest_webcam_scene(summary);
            crate::vision::store::set_latest_webcam_detections(detections.clone());

            // Gate: only store to memory if the event passes cooldown +
            // confidence + importance. This prevents spam but keeps the
            // live scene fresh.
            if let Some(event) = vision_gate.process_detections(detections) {
                if let Some(ref store) = memory_store {
                    let _ = crate::vision::store_visual_event(store, &event);
                    eprintln!("[AURA_VISION] Stored visual event: {}", event.text);
                }
            }
        }
        EngineMsg::HealMemory { reply } => {
            let json =
                memory_health::check_and_heal(engine, memory_store.as_ref(), prefilled_memories);
            if let Some(reply) = reply {
                let _ = reply.send(json);
            }
        }
        _ => {}
    }
}

/// If the device is critically low on memory, run the auto-healer before
/// starting a heavy LLM turn. This prevents the system from reaching the
/// "please close something memory full" state mid-generation.
fn maybe_heal_memory_pressure(
    engine: &mut LlamaEngine,
    memory_store: &Option<Arc<MemoryStore>>,
    prefilled_memories: &mut Option<Vec<String>>,
) {
    let snapshot = memory_health::read_memory_snapshot();
    let pressure = memory_health::pressure_from_snapshot(&snapshot);
    if pressure != MemoryPressure::Healthy {
        eprintln!(
            "[AURA_WORKER] {:?} memory before chat ({:.2} GB free / {:.2} GB total) — auto-healing.",
            pressure,
            snapshot.available_gb(),
            snapshot.total_gb()
        );
        let _ = memory_health::check_and_heal(engine, memory_store.as_ref(), prefilled_memories);
    }
}
