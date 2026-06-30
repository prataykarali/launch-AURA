#![allow(clippy::too_many_arguments)]

use std::sync::atomic::Ordering;

use crate::api::chat::output::clean_model_output_prefix;
use crate::api::chat::reply::grounded_fallback_for_weak_response;
use crate::frb_generated::StreamSink;
use crate::llama_engine::{LlamaEngine, CANCEL_FLAG};
use crate::memory::ReplyPlan;
use crate::performance_profile::PerformanceProfile;

pub(crate) fn run_generation(
    engine: &mut LlamaEngine,
    generation_prompt: &str,
    persona_examples: Vec<String>,
    max_tokens: i32,
    is_bar: bool,
    perf: &PerformanceProfile,
    plan: &ReplyPlan,
    clean_prompt: &str,
    fallback_memories: &[String],
    sink: &mut StreamSink<String>,
) -> Result<String, Box<dyn std::error::Error>> {
    if is_bar {
        generate_bar(
            engine,
            generation_prompt,
            persona_examples,
            max_tokens,
            perf,
            plan,
            clean_prompt,
            fallback_memories,
            sink,
        )
    } else {
        generate_full(
            engine,
            generation_prompt,
            persona_examples,
            max_tokens,
            perf,
            plan,
            sink,
        )
    }
}

fn generate_bar(
    engine: &mut LlamaEngine,
    generation_prompt: &str,
    persona_examples: Vec<String>,
    max_tokens: i32,
    _perf: &PerformanceProfile,
    _plan: &ReplyPlan,
    clean_prompt: &str,
    fallback_memories: &[String],
    sink: &mut StreamSink<String>,
) -> Result<String, Box<dyn std::error::Error>> {
    // No Rust-side timeout — Flutter already guards with a 60s first-token
    // timeout and a 20s inter-token timeout. The Rust timeout was firing
    // "try a shorter question" before Flutter could handle it gracefully.
    let mut inner_response = String::new();
    engine.generate_with_context(
        generation_prompt,
        persona_examples,
        max_tokens,
        |tok| {
            inner_response.push_str(&tok);
        },
    )?;

    inner_response = clean_model_output_prefix(&inner_response)
        .trim()
        .to_string();

    if inner_response.is_empty() {
        if let Some(fallback) =
            grounded_fallback_for_weak_response(clean_prompt, &inner_response, fallback_memories)
        {
            eprintln!(
                "[AURA_WORKER] Replaced weak brief response with grounded fallback: {:?}",
                fallback
            );
            let _ = sink.add(fallback.clone());
            return Ok(fallback);
        }
    }

    let _ = sink.add(inner_response.clone());
    Ok(inner_response)
}

fn generate_full(
    engine: &mut LlamaEngine,
    generation_prompt: &str,
    persona_examples: Vec<String>,
    max_tokens: i32,
    perf: &PerformanceProfile,
    plan: &ReplyPlan,
    sink: &mut StreamSink<String>,
) -> Result<String, Box<dyn std::error::Error>> {
    let mut full_response = String::new();
    let mut stripped_leading_label = false;
    let mut first_token_sent = false;

    engine.generate_with_context(
        generation_prompt,
        persona_examples,
        max_tokens,
        |tok| {
            if !first_token_sent && !tok.trim().is_empty() {
                first_token_sent = true;
            }

            let tok_out = if !stripped_leading_label {
                full_response.push_str(&tok);
                if full_response.len() >= 5 {
                    let out = clean_model_output_prefix(&full_response);
                    full_response = out.clone();
                    stripped_leading_label = true;
                    Some(out)
                } else {
                    None
                }
            } else {
                full_response.push_str(&tok);
                Some(tok)
            };

            if let Some(out) = tok_out {
                let _ = sink.add(out);
            }
        },
    )?;

    // ── Multi-turn LOOP ──────────────────────────────────────────────────────
    // Instead of a fixed number of continuation passes, LOOP the inference:
    // keep generating 48-token paragraphs until the model emits EOS (it
    // DECIDES when the answer is complete) or we hit the safety ceiling.
    // This gives stories/explanations exactly as many turns as they need.
    const CONTINUATION_PASS_TOKENS: i32 = 48;
    const MAX_CONTINUATION_TOKENS: i32 = 512; // safety ceiling — ~10 paragraphs
    let should_loop = perf.allow_continuation && plan.continuation > 0;
    if should_loop {
        let mut total_continuation = 0i32;
        let mut pass = 0u32;
        while !CANCEL_FLAG.load(Ordering::Relaxed)
            && total_continuation < MAX_CONTINUATION_TOKENS
        {
            pass += 1;
            eprintln!(
                "[AURA_WORKER] continuation loop {} (+{} tok, {} total)",
                pass, CONTINUATION_PASS_TOKENS, total_continuation
            );
            let generated = engine.generate_continue(CONTINUATION_PASS_TOKENS, |tok| {
                if !first_token_sent && !tok.trim().is_empty() {
                    first_token_sent = true;
                }
                full_response.push_str(&tok);
                let _ = sink.add(tok);
            })?;
            total_continuation += generated as i32;
            // Model stopped early (EOS / stop token) → it decided it's done.
            if generated < CONTINUATION_PASS_TOKENS {
                eprintln!(
                    "[AURA_WORKER] continuation loop ended at pass {} (EOS) — {} total continuation tokens",
                    pass, total_continuation
                );
                break;
            }
        }
    }

    Ok(full_response)
}
