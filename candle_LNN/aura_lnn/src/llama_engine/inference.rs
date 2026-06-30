#![allow(deprecated)]

use std::error::Error;
use std::sync::atomic::Ordering;

use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::Special;
use llama_cpp_2::token::LlamaToken;

use crate::performance_profile::PerformanceTier;

use super::LlamaEngine;
use super::CANCEL_FLAG;

impl LlamaEngine {
    pub fn generate_stream<F>(
        &mut self,
        prompt: &str,
        on_token: F,
    ) -> Result<String, Box<dyn Error>>
    where
        F: FnMut(String),
    {
        self.generate_with_context(prompt, vec![], 512, on_token)
    }

    /// Continue generation for up to `max_new_tokens` MORE tokens, picking up
    /// from where the last `generate_with_context` / `generate_continue` left
    /// off (uses the existing KV cache / recurrent state — no prompt re-decode).
    ///
    /// This is the multi-loop primitive for the variable-length planner: when a
    /// "explain X" answer is still mid-sentence at the first-pass cap, the worker
    /// calls this with the next budget slice and the model just keeps writing.
    /// The token callback receives each new token exactly like the first pass.
    ///
    /// Returns the number of tokens actually generated this pass (0 if it
    /// stopped early on EOS / a stop token / hitting the context window).
    pub fn generate_continue<F>(
        &mut self,
        max_new_tokens: i32,
        on_token: F,
    ) -> Result<i32, Box<dyn Error>>
    where
        F: FnMut(String),
    {
        let mut on_token = on_token;
        let n_ctx = self.context.n_ctx() as usize;

        // If we're already at the context ceiling there's nothing to continue.
        if (self.n_past as usize) >= n_ctx || max_new_tokens <= 0 {
            return Ok(0);
        }

        let mut generated = 0;
        let eos_token = self.model.token_eos();
        let mut batch = LlamaBatch::new(1, 1);
        let mut inside_think = false;
        let mut n_past = self.n_past;

        loop {
            if CANCEL_FLAG.load(Ordering::Relaxed) {
                break;
            }
            if (n_past as usize) >= n_ctx {
                break;
            }
            if generated >= max_new_tokens {
                break;
            }

            let current_token = self.sampler.sample(&self.context, -1);
            if current_token == eos_token || self.is_stop_token(current_token) {
                break;
            }

            let token_text = self
                .model
                .token_to_str(current_token, Special::Plaintext)
                .unwrap_or_default();
            if token_text.contains("<think>") || token_text.contains("<|think|>") {
                inside_think = true;
            }
            if token_text.contains("</think>") || token_text.contains("<|/think|>") {
                inside_think = false;
            } else if !inside_think {
                on_token(token_text);
            }

            batch.clear();
            batch.add(current_token, n_past, &[0], true)?;
            n_past += 1;

            self.context.decode(&mut batch)?;
            self.sampler.accept(current_token);
            generated += 1;
        }

        self.n_past = n_past;
        Ok(generated)
    }

    pub(super) fn is_stop_token(&self, token_id: LlamaToken) -> bool {
        let text = self
            .model
            .token_to_str(token_id, Special::Tokenize)
            .unwrap_or_default();
        text.contains("<|im_end|>") || text.contains("<|endoftext|>") || text.trim() == "</s>"
    }

    pub(super) fn observe_generation_speed(&mut self, tps: f64, generated: i32) {
        if generated < 24 || !tps.is_finite() {
            return;
        }

        let slow_threshold = match self.profile.tier {
            PerformanceTier::Strong => 9.0,
            PerformanceTier::Balanced => 6.0,
            PerformanceTier::Constrained => 3.5,
        };

        if tps >= slow_threshold {
            self.slow_generation_streak = 0;
            return;
        }

        self.slow_generation_streak = self.slow_generation_streak.saturating_add(1);
        if self.slow_generation_streak < 2 {
            return;
        }

        let next = self.profile.smooth_fallback();
        if next.label != self.profile.label {
            eprintln!(
                "[AURA_PERF] lowering runtime profile {} -> {} after slow decode ({:.2} tok/s)",
                self.profile.label, next.label, tps
            );
            self.profile = next;
            self.slow_generation_streak = 0;
        }
    }
}
