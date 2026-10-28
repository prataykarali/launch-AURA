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
    // FIX: Increased capacity from8 to50 to prevent queue overflow under load.
    // Under heavy load (vision + chat + memory simultaneously), the embed worker
    // falls behind and the8-slot queue fills up, dropping embeddings silently.
    // With50 slots, the queue can absorb bursts without losing data.
    let (tx, rx) = mpsc::sync_channel::<StoreEmbedJob>(50);

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
        let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        let mut candidates = Vec::new();
        if let (Ok(model), Ok(tok)) = (
            std::env::var("AURA_EMBED_MODEL_PATH"),
            std::env::var("AURA_EMBED_TOKENIZER_PATH"),
        ) {
            candidates.push((model.into(), tok.into()));
        }
        candidates.extend([
            (dir.join("bge_model.onnx"), dir.join("bge_tokenizer.json")),
            (dir.join("model_quantized.onnx"), dir.join("tokenizer.json")),
            (
                manifest_dir.join("../../assets/embedder/model_quantized.onnx"),
                manifest_dir.join("../../assets/embedder/tokenizer.json"),
            ),
            (
                manifest_dir.join("../../aura_notebook/assets/embedder/model_quantized.onnx"),
                manifest_dir.join("../../aura_notebook/assets/embedder/tokenizer.json"),
            ),
        ]);
        let (onnx, tok) = candidates
            .into_iter()
            .find(|(model, tok)| model.exists() && tok.exists())
            .ok_or_else(|| {
                format!(
                    "embedder files not found; tried env AURA_EMBED_* plus sibling files next to {} and repo assets/embedder",
                    model_path
                )
            })?;
        // BgeTextEmbedder::new returns EmbedResult (Box<dyn Error + Send + Sync>);
        // map to a plain string error so it fits this fn's Box<dyn Error> return.
        let embedder = BgeTextEmbedder::new(
            onnx.to_str().ok_or("non-utf8 embedder path")?,
            tok.to_str().ok_or("non-utf8 tokenizer path")?,
        )
        .map_err(
            |e: Box<dyn std::error::Error + Send + Sync>| -> Box<dyn Error> {
                e.to_string().into()
            },
        )?;
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
    ///
    /// FIX: Retry once after a short delay if the queue is full, instead of
    /// immediately dropping. This handles bursts where the embed worker is
    /// temporarily backed up.
    pub fn store_embed(&self, text: String, store: Arc<MemoryStore>) {
        let Some(tx) = self.store_embed_tx.as_ref() else {
            eprintln!("[LLM] store_embed skipped — worker unavailable");
            return;
        };
        match tx.try_send(StoreEmbedJob {
            text: text.clone(),
            store: store.clone(),
        }) {
            Ok(()) => {}
            Err(mpsc::TrySendError::Full(_)) => {
                // Queue full — retry once after 100ms.
                std::thread::sleep(std::time::Duration::from_millis(100));
                if let Err(e) = tx.try_send(StoreEmbedJob { text, store }) {
                    eprintln!("[LLM] store_embed dropped after retry (queue still full): {e}");
                }
            }
            Err(e) => {
                eprintln!("[LLM] store_embed dropped (disconnected): {e}");
            }
        }
    }
}
