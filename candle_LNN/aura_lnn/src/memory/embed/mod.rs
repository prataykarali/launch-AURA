// src/memory/embed/mod.rs - Dedicated embedding model for semantic memory retrieval.
//
// AURA's text memory retrieval (RAG) now runs on a REAL embedding model —
// bge-small-en-v1.5 (384-dim, ~44MB fp32 ONNX) — instead of the chat LLM's
// noisy mean-pooled hidden states. This module owns that model through ONNX
// Runtime (`ort`).
//
// Architecture is deliberately modality-agnostic:
//
//     ┌─────────────┐  embed() -> Vec<f32>   ┌───────────────┐
//     │  Embedder   │◀────────────────────── │   callers      │
//     │   (trait)   │                        │ (store/RAG,    │
//     └─────┬───────┘                        │  vision, ...)  │
//           │                                 └───────────────┘
//     ┌─────┴────────────┬───────────────────────┐
//     │                  │                       │
// ┌───▼────────────┐  ┌──▼─────────────┐   ┌─────▼──────────┐ (future)
// │ BgeTextEmbedder │  │  ... text ...   │   │ ClipVisionEmbed │
// │  (this module)  │  │                 │   │   (Phase V)     │
// └────────────────┘  └─────────────────┘   └────────────────┘
//
// Text and vision vectors are stored in SEPARATE tables / dimensions, so text
// cosine search never collides with image cosine search. Adding CLIP later
// reuses 100% of the `ort` session + tokenizer plumbing here.

use std::error::Error;

/// Embedding dimensionality for bge-small-en-v1.5 (BertModel, hidden_size=384).
/// Stored on every embedder so the store can validate vector length on insert
/// and skip stale rows with a different dim during the one-time re-embed.
pub const TEXT_EMBED_DIM: usize = 384;

/// Thread-safe alias for our error boxes. `tokenizers` and `ort` errors are
/// converted into this via `.to_string()` because the crates' native error
/// types are not `Send + Sync`, which the background store-embed worker needs.
pub type EmbedResult<T> = Result<T, Box<dyn Error + Send + Sync>>;

pub(crate) fn err<E: std::fmt::Display>(ctx: &str, e: E) -> Box<dyn Error + Send + Sync> {
    format!("{ctx}: {e}").into()
}

/// A modality-agnostic embedder. Produces an L2-normalized vector for a piece
/// of content, so callers can use plain dot-product as cosine similarity.
///
/// Implementations are `Send + Sync` so one embedder can be shared across the
/// chat thread (query embeds) and the background store-embed worker (turn
/// embeds) behind an `Arc`.
pub trait Embedder: Send + Sync {
    /// Embed `content` into a single L2-normalized unit vector (passage form).
    fn embed(&self, content: &str) -> EmbedResult<Vec<f32>>;

    /// Dimensionality of the vectors this embedder produces.
    fn dim(&self) -> usize;

    /// Embed a passage (default implementation delegates to `embed`).
    fn embed_passage(&self, content: &str) -> EmbedResult<Vec<f32>> {
        self.embed(content)
    }

    /// Embed a query (default implementation delegates to `embed`).
    fn embed_query(&self, query: &str) -> EmbedResult<Vec<f32>> {
        self.embed(query)
    }
}

/// No-op embedder used as a fallback when the real BGE embedder cannot be
/// loaded on Android. Chat still works; semantic memory retrieval degrades to
/// recency-only because all vectors are zero.
pub struct NoOpEmbedder {
    dim: usize,
}

impl NoOpEmbedder {
    pub fn new(dim: usize) -> Self {
        Self { dim }
    }
}

impl Embedder for NoOpEmbedder {
    fn embed(&self, _content: &str) -> EmbedResult<Vec<f32>> {
        Ok(vec![0.0f32; self.dim])
    }
    fn dim(&self) -> usize {
        self.dim
    }
}

mod model;
mod plan;
mod plan_budgets;
mod scheduler;

pub use model::BgeTextEmbedder;
pub use plan::{plan_reply, ReplyPlan};
pub use scheduler::RLScheduler;
