use std::error::Error;
use std::sync::mpsc::{self, SyncSender};
use std::sync::Arc;

use crate::memory::store::MemoryStore;
use crate::memory::{BgeTextEmbedder, Embedder};

use super::LlamaEngine;

pub(super) struct StoreEmbedJob {
    text: String,
    store: Arc<MemoryStore>,
}

pub(super) fn spawn_store_embed_worker(
    embedder: Arc<dyn Embedder + Send + Sync>,
) -> Option<SyncSender<StoreEmbedJob>> {
    let (tx, rx) = mpsc::sync_channel::<StoreEmbedJob>(8);

    std::thread::Builder::new()
        .name("aura-store-embed".into())
        .stack_size(16 * 1024 * 1024)
        .spawn(move || {
            eprintln!("[STORE_EMBED] worker ready (bge-base-en-v1.5 ONNX)");
            while let Ok(job) = rx.recv() {
                match embedder.embed_passage(&job.text) {
                    Ok(emb) => {
                        if let Err(e) = job.store.insert_vec_memory(&job.text, &emb) {
                            eprintln!("[STORE_EMBED] insert_vec_memory failed: {e}");
                        }
                    }
                    Err(e) => {
                        eprintln!("[STORE_EMBED] embed failed for a turn: {e}");
                    }
                }
            }
            eprintln!("[STORE_EMBED] worker exiting (channel closed)");
        })
        .map(|_| tx)
        .map_err(|e| {
            eprintln!("[STORE_EMBED] failed to spawn worker: {e}");
            e
        })
        .ok()
}

impl LlamaEngine {
    pub fn load_sibling_embedder(
        model_path: &str,
    ) -> Result<std::sync::Arc<BgeTextEmbedder>, Box<dyn Error>> {
        let dir = std::path::Path::new(model_path)
            .parent()
            .unwrap_or_else(|| std::path::Path::new("."));
        let onnx = dir.join("bge_model.onnx");
        let tok = dir.join("bge_tokenizer.json");
        // BgeTextEmbedder::new returns EmbedResult (Box<dyn Error + Send + Sync>);
        // map to a plain string error so it fits this fn's Box<dyn Error> return.
        let embedder = BgeTextEmbedder::new(
            onnx.to_str().ok_or("non-utf8 embedder path")?,
            tok.to_str().ok_or("non-utf8 tokenizer path")?,
        )
        .map_err(|e: Box<dyn std::error::Error + Send + Sync>| -> Box<dyn Error> {
            e.to_string().into()
        })?;
        Ok(std::sync::Arc::new(embedder))
    }

    /// Produce a normalized embedding for `text` using the dedicated bge-base-en-v1.5
    /// ONNX embedder. Synchronous (~150ms desktop / ~300ms Android) and runs on
    /// the chat thread — it MUST complete before memory retrieval. Completely
    /// independent of the chat KV cache, so it never disturbs the live
    /// conversation. Returns a unit vector so dot-product == cosine similarity.
    /// Access the shared embedder (for operations outside the normal chat
    /// path — e.g. memory-note embedding on demand from the worker). Returns
    /// `None` only if the engine was built with the no-op fallback, in which
    /// case callers should skip embedding.
    pub fn embedder(&self) -> Option<std::sync::Arc<dyn Embedder + Send + Sync>> {
        Some(self.embedder.clone())
    }

    pub fn embed_query(&self, text: &str) -> Result<Vec<f32>, Box<dyn Error + Send + Sync>> {
        self.embedder.embed_query(text)
    }

    /// Fire-and-forget: enqueue a turn to be embedded on the background worker
    /// and stored in `vec_memory`. NEVER blocks the chat thread — the worker
    /// uses the same shared bge embedder (~150ms off-thread). If the queue is
    /// full or the worker is dead, the job is silently dropped (memory RAG
    /// degrades gracefully to recency-only retrieval).
    pub fn store_embed(&self, text: String, store: Arc<MemoryStore>) {
        let Some(tx) = self.store_embed_tx.as_ref() else {
            eprintln!("[LLM] store_embed skipped — worker unavailable");
            return;
        };
        if let Err(e) = tx.try_send(StoreEmbedJob { text, store }) {
            // Queue full (worker backed up) or disconnected (worker died).
            // Either way: drop the job; next turn will retry.
            eprintln!("[LLM] store_embed dropped (queue full/disconnected): {e}");
        }
    }
}
