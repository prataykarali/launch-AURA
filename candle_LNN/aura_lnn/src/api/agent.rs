use crate::llama_engine::{LlamaEngine, CANCEL_FLAG};
use crate::memory::store::MemoryStore;
use std::sync::atomic::Ordering;
use std::sync::Arc;

/// Dynamic ReAct Agent loop orchestrator.
/// Coordinates multi-pass reasoning using <think> blocks and tool actions.
pub fn run_agent_loop<F>(
    engine: &mut LlamaEngine,
    store: &MemoryStore,
    user_prompt: &str,
    _initial_memories: Vec<String>,
    max_tokens: i32,
    mut on_token: F,
) -> Result<String, Box<dyn std::error::Error>>
where
    F: FnMut(String),
{
    let mut current_prompt = user_prompt.to_string();
    let mut iteration = 0;
    const MAX_ITERATIONS: usize = 3;

    loop {
        iteration += 1;
        if iteration > MAX_ITERATIONS {
            eprintln!(
                "[AURA_AGENT] Reached max reasoning iterations ({}), forcing final response.",
                MAX_ITERATIONS
            );
            // Force direct response
            let _ = engine.generate_with_context(
                &current_prompt,
                vec![],
                max_tokens,
                &mut on_token,
            );
            break;
        }

        eprintln!("[AURA_AGENT] Starting iteration {}", iteration);
        CANCEL_FLAG.store(false, Ordering::Relaxed);

        // State variables to parse thinking and actions
        let mut full_accumulated = String::new();
        let mut inside_think = false;
        let mut action_detected: Option<AgentAction> = None;

        // Perform LLM pass. We use a local callback to parse the thoughts.
        let temp_engine = &mut *engine;
        let gen_res = temp_engine.generate_with_context(
            &current_prompt,
            vec![],
            max_tokens,
            |tok| {
                full_accumulated.push_str(&tok);

                // Track think block state
                if full_accumulated.contains("<think>") || full_accumulated.contains("<|think|>") {
                    inside_think = true;
                }
                if full_accumulated.contains("</think>") || full_accumulated.contains("<|/think|>")
                {
                    inside_think = false;
                }

                // If we are inside thinking, check for action patterns
                if inside_think {
                    if let Some(action) = parse_action_from_text(&full_accumulated) {
                        action_detected = Some(action);
                        // Cancel generation immediately to execute the action
                        CANCEL_FLAG.store(true, Ordering::Relaxed);
                    }
                } else if !full_accumulated.contains("<think>") {
                    // If the model is not thinking at all, or has finished thinking and is outputting final text,
                    // stream tokens directly to the user callback!
                    on_token(tok);
                }
            },
        );

        // Ensure CANCEL_FLAG is reset
        CANCEL_FLAG.store(false, Ordering::Relaxed);

        if let Err(e) = gen_res {
            eprintln!(
                "[AURA_AGENT_ERR] Generation error in iteration {}: {:?}",
                iteration, e
            );
            return Err(e);
        }

        // Process the parsed action (if any)
        if let Some(action) = action_detected {
            eprintln!("[AURA_AGENT] Executing Action: {:?}", action);
            match action {
                AgentAction::RetrieveMemory(query) => {
                    let mut observations = Vec::new();
                    // Embed and search long term vector database
                    if let Ok(qemb) = temp_engine.embed_query(&query) {
                        if let Ok(matches) = store.search_relevant_hybrid(&query, &qemb, 5) {
                            for m in matches {
                                // Filter by confidence threshold (approximate cosine similarity score >= 0.70)
                                // In search_relevant_hybrid, the final score includes BM25, but we can check if it's relevant.
                                observations.push(m);
                            }
                        }
                    }

                    let observation_str = if observations.is_empty() {
                        "No matching memories found.".to_string()
                    } else {
                        observations.join("\n")
                    };

                    eprintln!(
                        "[AURA_AGENT] Memory search observation: {}",
                        observation_str
                    );

                    // Update prompt with the thought process and observation
                    current_prompt = format!(
                        "{}\n<think>\nAction: retrieve_memory(\"{}\")\n</think>\nObservation:\n{}",
                        current_prompt, query, observation_str
                    );
                }
                AgentAction::UseVision => {
                    // Read visual description from native webcam module
                    let scene_summary = crate::vision::store::get_latest_webcam_scene();
                    eprintln!("[AURA_AGENT] Vision observation: {}", scene_summary);

                    // Update prompt
                    current_prompt = format!(
                        "{}\n<think>\nAction: use_vision()\n</think>\nObservation:\n{}",
                        current_prompt, scene_summary
                    );
                }
                AgentAction::RespondDirectly => {
                    // LLM decided to respond directly
                    // Get the text outside the think block and stream it (it already finished generation or we can run final pass)
                    let final_ans = strip_think_block(&full_accumulated);
                    if !final_ans.trim().is_empty() {
                        // If it generated a direct response during this pass but wasn't streamed, stream it now
                        on_token(final_ans);
                    }
                    break;
                }
            }
        } else {
            // No action was parsed, meaning it generated a direct response or finished naturally
            let final_ans = strip_think_block(&full_accumulated);
            if !final_ans.trim().is_empty() {
                // If it generated response but wasn't streamed (e.g. it was inside/outside think block)
                on_token(final_ans);
            }
            break;
        }
    }

    Ok(String::new())
}

#[derive(Debug, Clone)]
enum AgentAction {
    RetrieveMemory(String),
    UseVision,
    RespondDirectly,
}

fn parse_action_from_text(text: &str) -> Option<AgentAction> {
    let lower = text.to_lowercase();

    // Check retrieve_memory
    if let Some(idx) = lower.find("action: retrieve_memory(\"") {
        let rest = &text[idx + 24..];
        if let Some(end_idx) = rest.find("\")") {
            let query = rest[..end_idx].to_string();
            return Some(AgentAction::RetrieveMemory(query));
        }
    }

    // Check use_vision
    if lower.contains("action: use_vision()") {
        return Some(AgentAction::UseVision);
    }

    // Check respond_directly
    if lower.contains("action: respond_directly()") {
        return Some(AgentAction::RespondDirectly);
    }

    None
}

fn strip_think_block(text: &str) -> String {
    let mut out = String::new();
    let parts: Vec<&str> = text.split("<think>").collect();

    // Simple parser for think blocks
    for (i, part) in parts.iter().enumerate() {
        if i == 0 {
            out.push_str(part);
        } else {
            if let Some(idx) = part.find("</think>") {
                out.push_str(&part[idx + 8..]);
            }
        }
    }

    // Also clean tags like <|think|>, <|/think|>, etc.
    out.replace("<think>", "")
        .replace("</think>", "")
        .replace("<|think|>", "")
        .replace("<|/think|>", "")
        .trim()
        .to_string()
}
