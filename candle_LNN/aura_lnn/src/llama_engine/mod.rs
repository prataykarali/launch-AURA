use std::sync::atomic::AtomicBool;
use std::sync::mpsc::SyncSender;
use std::sync::Arc;

use llama_cpp_2::context::LlamaContext;
use llama_cpp_2::model::LlamaModel;
use llama_cpp_2::sampling::LlamaSampler;
use llama_cpp_2::token::LlamaToken;

use crate::memory::Embedder;
use crate::performance_profile::PerformanceProfile;

use self::embedding::StoreEmbedJob;

pub static CANCEL_FLAG: AtomicBool = AtomicBool::new(false);

pub struct LlamaEngine {
    model: &'static LlamaModel,
    context: LlamaContext<'static>,
    sampler: LlamaSampler,
    system_tokens: Vec<LlamaToken>,
    n_past: i32,
    // Dedicated bge-base-en-v1.5 text embedder (ONNX Runtime), or a no-op
    // fallback on Android when the ONNX runtime cannot load. Shared with the
    // background store-embed worker. This REPLACES the old chat-model
    // mean-pooled embeddings (embed_ctx) which were noisy and slow.
    embedder: Arc<dyn Embedder + Send + Sync>,
    // Background store-embed queue. None if the worker failed to spin up (then
    // store-embeds are silently skipped — memory RAG degrades to recency only).
    store_embed_tx: Option<SyncSender<StoreEmbedJob>>,
    profile: PerformanceProfile,
    slow_generation_streak: u8,
}

mod embedding;
mod generate;
mod inference;
mod model;
mod state;

impl LlamaEngine {
    pub fn performance_profile(&self) -> PerformanceProfile {
        self.profile
    }
}
