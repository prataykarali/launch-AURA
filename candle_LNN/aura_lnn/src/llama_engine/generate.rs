#![allow(deprecated)]

use std::error::Error;
use std::sync::atomic::Ordering;

use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::{AddBos, Special};

use super::LlamaEngine;
use super::CANCEL_FLAG;

impl LlamaEngine {
    /// Generate a reply from the model.
    ///
    /// Memory is NEVER fed into the model here — the prompt the model sees is
    /// just the persona few-shot examples + the user message. Relevant memory is
    /// retrieved by the embedder and APPENDED to the reply afterwards by the
    /// caller (see `chat::turn`). This keeps the decoded prompt tiny so the
    /// first token arrives fast and per-token latency stays bounded.
    pub fn generate_with_context<F>(
        &mut self,
        prompt: &str,
        persona_examples: Vec<String>,
        max_new_tokens: i32,
        on_token: F,
    ) -> Result<String, Box<dyn Error>>
    where
        F: FnMut(String),
    {
        let mut on_token = on_token;
        eprintln!("[LLM] generate_with_context: prompt len={}", prompt.len());
        #[cfg(target_os = "android")]
        log::info!(
            "[LLM] generate_with_context: prompt len={} max_new_tokens={}",
            prompt.len(),
            max_new_tokens
        );

        if self.system_tokens.is_empty() {
            self.warmup()?;
        }

        // Build the user block:
        //   <|im_start|>user
        //   [persona examples]
        //   <user message>
        //   |im_end|>
        //   <|im_start|>assistant
        // No facts / no memory instruction / no prefill — memory is appended
        // post-generation, never injected into the model context.

        let mut context_to_decode = String::new();
        context_to_decode.push_str("<|im_start|>user\n");

        let has_examples = !persona_examples.is_empty();
        if has_examples {
            context_to_decode.push_str("Examples of how AURA responds:\n");
            for ex in &persona_examples {
                context_to_decode.push_str(ex);
                context_to_decode.push('\n');
            }
            context_to_decode.push('\n');
        }

        context_to_decode.push_str(prompt);
        context_to_decode.push_str("<|im_end|>\n");
        context_to_decode.push_str("<|im_start|>assistant\n");

        let user_tokens = self.model.str_to_token(&context_to_decode, AddBos::Never)?;
        if user_tokens.is_empty() {
            return Ok(String::new());
        }

        let n_ctx = self.context.n_ctx() as usize;

        // Proactive context reset: for recurrent models, decode cost grows with
        // n_past and the recurrent state cannot be partially rewound. Reset at a
        // low watermark before the turn so latency stays bounded.
        const RESET_MARGIN_FRAC: usize = 4;
        let headroom_needed = user_tokens.len() + (max_new_tokens as usize) + 32;
        let reset_watermark = n_ctx.saturating_sub(n_ctx / RESET_MARGIN_FRAC);
        let should_reset = (self.n_past as usize) + headroom_needed >= n_ctx
            || (self.n_past as usize) > reset_watermark;
        if should_reset {
            eprintln!(
                "[LLM] Context reset: n_past={} (watermark={}, n_ctx={}) — resetting between turns for stable per-token latency",
                self.n_past, reset_watermark, n_ctx
            );
            self.reset_state();
            self.warmup()?;
        }

        let n_batch = self.context.n_batch() as usize;
        let mut n_past = self.n_past;
        let decode_start = std::time::Instant::now();

        for chunk in user_tokens.chunks(n_batch) {
            let mut batch = LlamaBatch::new(chunk.len(), 1);
            for (i, token) in chunk.iter().enumerate() {
                batch.add(*token, n_past + i as i32, &[0], i == chunk.len() - 1)?;
            }
            self.context.decode(&mut batch)?;
            n_past += chunk.len() as i32;
        }

        let ttft = decode_start.elapsed();
        eprintln!(
            "[LLM] User prompt ({} tokens) decoded in {:?}",
            user_tokens.len(), ttft
        );
        #[cfg(target_os = "android")]
        log::info!(
            "[LLM] User prompt ({} tokens) decoded in {:?}",
            user_tokens.len(),
            ttft
        );

        let mut generated = 0;
        let start_time = std::time::Instant::now();
        let eos_token = self.model.token_eos();
        let mut batch = LlamaBatch::new(1, 1);
        let mut inside_think = false;

        loop {
            if CANCEL_FLAG.load(Ordering::Relaxed) {
                eprintln!("[LLM] generation cancelled");
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
            if token_text.contains("<|think|>") {
                inside_think = true;
            }
            if token_text.contains("<|/think|>") {
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

        let duration = start_time.elapsed();
        let tps = generated as f64 / duration.as_secs_f64();
        self.observe_generation_speed(tps, generated);
        eprintln!(
            "[LLM] generated {} tokens in {:.2?}, speed: {:.2} tokens/s",
            generated, duration, tps
        );
        #[cfg(target_os = "android")]
        log::info!(
            "[LLM] generated {} tokens in {:.2?}, speed: {:.2} tokens/s",
            generated, duration, tps
        );

        self.n_past = n_past;
        Ok(String::new())
    }
}
