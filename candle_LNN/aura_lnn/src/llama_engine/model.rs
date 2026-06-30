use std::error::Error;
use std::num::NonZeroU32;
use std::sync::Arc;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::LlamaModel;
use llama_cpp_2::sampling::LlamaSampler;

use crate::device_backend::DeviceBackend;
use crate::memory::Embedder;
use crate::performance_profile::PerformanceProfile;

use super::embedding::spawn_store_embed_worker;
use super::LlamaEngine;

impl LlamaEngine {
    pub fn new(
        model_path: &str,
        _backend: DeviceBackend,
        n_ctx: u32,
        n_threads: i32,
        embedder: Arc<dyn Embedder + Send + Sync>,
    ) -> Result<Self, Box<dyn Error>> {
        static BACKEND: once_cell::sync::OnceCell<&'static LlamaBackend> =
            once_cell::sync::OnceCell::new();
        let backend = *BACKEND
            .get_or_try_init(|| {
                LlamaBackend::init().map(|b| -> &'static LlamaBackend { Box::leak(Box::new(b)) })
            })
            .map_err(|e| -> Box<dyn Error> { Box::new(e) })?;

        let mut model_params = LlamaModelParams::default();
        model_params = model_params.with_use_mmap(true);

        static MODEL_CACHE: once_cell::sync::OnceCell<&'static LlamaModel> =
            once_cell::sync::OnceCell::new();
        let model = *MODEL_CACHE.get_or_try_init(|| {
            LlamaModel::load_from_file(backend, model_path, &model_params)
                .map(|m| -> &'static LlamaModel { Box::leak(Box::new(m)) })
        })?;
        #[cfg(target_os = "android")]
        log::info!("[LLM] Model loaded from {}", model_path);

        let profile = PerformanceProfile::detect();
        let effective_ctx = n_ctx.min(profile.context_size);
        let effective_threads = n_threads.min(profile.llama_threads).max(1);
        let effective_batch = profile.batch_size.min(effective_ctx);
        eprintln!(
            "[AURA_PERF] profile={} cpu={} ram={:?} ctx={} batch={} threads={}",
            profile.label,
            profile.available_threads,
            profile.total_memory_bytes,
            effective_ctx,
            effective_batch,
            effective_threads
        );

        let ctx_params = LlamaContextParams::default()
            .with_n_ctx(NonZeroU32::new(effective_ctx))
            .with_n_batch(effective_batch)
            .with_n_threads(effective_threads)
            .with_n_threads_batch(effective_threads)
            .with_embeddings(false);
        let context = model.new_context(backend, ctx_params)?;
        #[cfg(target_os = "android")]
        log::info!("[LLM] Context created: ctx={} batch={} threads={}", effective_ctx, effective_batch, effective_threads);

        let sampler = LlamaSampler::chain_simple([
            LlamaSampler::penalties(
                crate::config::constants::REPEAT_LAST_N as i32,
                crate::config::constants::REPEAT_PENALTY,
                0.0,
                0.0,
            ),
            LlamaSampler::top_k(40),
            LlamaSampler::top_p(crate::config::constants::TOP_P as f32, 1),
            LlamaSampler::temp(crate::config::constants::TEMPERATURE as f32),
            LlamaSampler::dist(0),
        ]);

        // Spawn the background store-embed worker. It shares the SAME dedicated
        // bge embedder (ONNX Runtime, Send+Sync via internal Mutexes) — no more
        // per-thread llama embedding context. The worker just calls
        // embedder.embed_passage() and writes the row to vec_memory.
        let store_embed_tx = spawn_store_embed_worker(embedder.clone());

        Ok(Self {
            model,
            context,
            sampler,
            system_tokens: Vec::new(),
            n_past: 0,
            embedder,
            store_embed_tx,
            profile,
            slow_generation_streak: 0,
        })
    }
}
