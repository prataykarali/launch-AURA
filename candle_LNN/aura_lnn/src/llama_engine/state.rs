use std::error::Error;
use std::sync::atomic::Ordering;

use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::AddBos;

use crate::config::persona::system_prompt;

use super::LlamaEngine;
use super::CANCEL_FLAG;

impl LlamaEngine {
    pub fn warmup(&mut self) -> Result<(), Box<dyn Error>> {
        // Prefill system prompt
        let system_msg = format!("<|startoftext|><|im_start|>system\n{}<|im_end|>\n", system_prompt());
        let tokens = self.model.str_to_token(&system_msg, AddBos::Never)?;
        #[cfg(target_os = "android")]
        log::info!("[LLM] Warmup: {} system tokens to prefill", tokens.len());

        self.context.clear_kv_cache();

        let n_batch = self.context.n_batch() as usize;
        let mut n_past = 0;

        let start = std::time::Instant::now();
        for chunk in tokens.chunks(n_batch) {
            let mut batch = LlamaBatch::new(chunk.len(), 1);
            for (i, token) in chunk.iter().enumerate() {
                batch.add(*token, n_past + i as i32, &[0], i == chunk.len() - 1)?;
            }
            self.context.decode(&mut batch)?;
            n_past += chunk.len() as i32;
        }

        let elapsed = start.elapsed();

        self.system_tokens = tokens;
        self.n_past = n_past;
        eprintln!(
            "[LLM] Warmup complete: cached {} system tokens",
            self.n_past
        );
        #[cfg(target_os = "android")]
        log::info!(
            "[LLM] Warmup complete: cached {} system tokens in {:?}",
            self.n_past,
            elapsed
        );
        Ok(())
    }

    pub fn reset_state(&mut self) {
        CANCEL_FLAG.store(false, Ordering::Relaxed);
        // For recurrent models (LFM), partial sequence rewinding is not supported.
        // We must fully clear the cache and reset to 0.
        self.context.clear_kv_cache();
        self.system_tokens.clear();
        self.n_past = 0;
    }

    pub fn clear_kv_cache(&mut self) {
        self.context.clear_kv_cache();
    }

    pub fn prefill(&mut self, _partial: &str) {
        // DISABLED: This model uses a recurrent architecture (Gated Delta Net)
        // where the KV cache / recurrent state cannot be partially rewound.
        // Speculative prefill was writing tokens at n_past without updating it,
        // causing "inconsistent sequence positions" errors on the next real decode.
    }
}
