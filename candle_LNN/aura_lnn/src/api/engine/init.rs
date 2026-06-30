use std::sync::Arc;

use crate::api::chat::persona_retrieval::init_persona_index;
use crate::api::config::n_ctx_for_platform;
use crate::device_backend::DeviceBackend;
use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;
use crate::memory::BgeTextEmbedder;
use crate::memory::Embedder;

pub(crate) fn initialize_engine(
    model_path: &str,
    embed_model_path: &str,
    embed_tok_path: &str,
    db_path: &str,
) -> (Option<LlamaEngine>, Option<Arc<MemoryStore>>) {
    #[cfg(target_os = "android")]
    {
        android_logger::init_once(
            android_logger::Config::default()
                .with_max_level(log::LevelFilter::Info),
        );
    }
    eprintln!(
        "[AURA_WORKER] Initializing engine with model: {}",
        model_path
    );
    #[cfg(target_os = "android")]
    log::info!("[AURA_INIT] Initializing engine with model: {}", model_path);

    log_file_size(model_path, "[AURA_INIT] model file");
    log_file_size(embed_model_path, "[AURA_INIT] embedder model file");
    log_file_size(embed_tok_path, "[AURA_INIT] embedder tokenizer file");

    #[cfg(target_os = "android")]
    log::info!(
        "[AURA_INIT] embed paths: model='{}' tok='{}'",
        embed_model_path,
        embed_tok_path
    );

    let embedder_opt = load_embedder(embed_model_path, embed_tok_path);

    let embedder_for_engine: Arc<dyn Embedder + Send + Sync> = match embedder_opt {
        Some(ref e) => Arc::clone(e) as Arc<dyn Embedder + Send + Sync>,
        None => {
            #[cfg(target_os = "android")]
            {
                #[cfg(target_os = "android")]
                log::error!(
                    "[AURA_INIT] embedder unavailable — falling back to NoOp (memory will NOT work)"
                );
                eprintln!(
                    "[AURA_INIT] embedder unavailable on Android; using no-op embedder so chat can still load"
                );
                Arc::new(crate::memory::NoOpEmbedder::new(crate::memory::TEXT_EMBED_DIM))
            }
            #[cfg(not(target_os = "android"))]
            {
                eprintln!("[AURA_WORKER_ERR] dedicated embedder is required for the memory architecture");
                write_status(embed_model_path, "dedicated embedder is required for the memory architecture");
                return (None, None);
            }
        }
    };

    if let Some(ref embedder) = embedder_opt {
        if let Err(e) = init_persona_index(embedder) {
            eprintln!("[AURA_INIT] Persona retrieval index failed: {e}");
        } else {
            eprintln!("[AURA_INIT] Persona retrieval index ready");
        }
    }

    #[cfg(target_os = "android")]
    log::info!("[AURA_INIT] Creating LlamaEngine...");

    let engine_res = LlamaEngine::new(
        model_path,
        DeviceBackend::default_for_platform(),
        n_ctx_for_platform(),
        DeviceBackend::n_threads_for_platform(),
        embedder_for_engine,
    );

    let mut engine_opt = match engine_res {
        Ok(e) => {
            #[cfg(target_os = "android")]
            log::info!("[AURA_INIT] LlamaEngine created successfully");
            Some(e)
        }
        Err(e) => {
            let err_msg = format!("LlamaEngine::new failed: {:?}", e);
            eprintln!("[AURA_WORKER_ERR] Engine initialization failed: {:?}", e);
            #[cfg(target_os = "android")]
            log::error!("[AURA_INIT] Engine initialization failed: {:?}", e);
            write_status(embed_model_path, &err_msg);
            None
        }
    };

    if engine_opt.is_some() {
        write_status(embed_model_path, "success");
    }

    let memory_store = match MemoryStore::open(db_path) {
        Ok(store) => Some(Arc::new(store)),
        Err(e) => {
            let err_msg = format!("MemoryStore::open failed at {db_path}: {e}");
            eprintln!("[AURA_MEMORY_ERR] {err_msg}");
            write_status(embed_model_path, &err_msg);
            None
        }
    };

    if let (Some(ref store), Some(ref engine)) = (&memory_store, &engine_opt) {
        // Reseed from mirror file if the database has no turns
        if let Some(path) = store.mirror_path() {
            if path.exists() && store.turn_count().unwrap_or(0) == 0 {
                let seeded = crate::memory::notebook_file::reseed_from_file(store, &path);
                eprintln!(
                    "[AURA_INIT] Reseeded {} records from {}",
                    seeded,
                    path.display()
                );
            }
        }

        // Queue any turns that need embedding
        if let Ok(needing_embed) = store.get_turn_texts_needing_embedding() {
            if !needing_embed.is_empty() {
                eprintln!(
                    "[AURA_INIT] Queueing {} turns for background embedding",
                    needing_embed.len()
                );
                for text in needing_embed {
                    engine.store_embed(text, Arc::clone(store));
                }
            }
        }
    }

    if let Some(ref mut engine) = engine_opt {
        eprintln!("[AURA_WORKER] Warming up...");
        #[cfg(target_os = "android")]
        log::info!("[AURA_INIT] Warming up...");
        let _ = engine.warmup();
        #[cfg(target_os = "android")]
        log::info!("[AURA_INIT] Warmup returned");
    }

    (engine_opt, memory_store)
}

fn load_embedder(embed_model_path: &str, embed_tok_path: &str) -> Option<Arc<BgeTextEmbedder>> {
    if embed_model_path.is_empty() || embed_tok_path.is_empty() {
        let err_msg = "no embedder paths provided (semantic memory disabled)";
        eprintln!("[AURA_EMBED] {}", err_msg);
        write_status(embed_model_path, err_msg);
        return None;
    }

    #[cfg(target_os = "android")]
    {
        // On Android the prebuilt ONNX Runtime can hang during session creation.
        // Load it in a separate thread with a short timeout so the engine can still start.
        return load_embedder_with_timeout(
            embed_model_path,
            embed_tok_path,
            std::time::Duration::from_secs(60),
        );
    }

    #[cfg(not(target_os = "android"))]
    match BgeTextEmbedder::new(embed_model_path, embed_tok_path) {
        Ok(e) => {
            eprintln!(
                "[AURA_EMBED] bge-small ONNX embedder loaded ({:?} dim) from {}",
                e.dim(),
                embed_model_path
            );
            Some(Arc::new(e))
        }
        Err(e) => {
            let err_msg = format!("embedder load failed: {e}");
            eprintln!("[AURA_EMBED] WARN: {err_msg}");
            write_status(embed_model_path, &err_msg);
            None
        }
    }
}

#[cfg(target_os = "android")]
fn load_embedder_with_timeout(
    embed_model_path: &str,
    embed_tok_path: &str,
    timeout: std::time::Duration,
) -> Option<Arc<BgeTextEmbedder>> {
    let model_path = embed_model_path.to_string();
    let tok_path = embed_tok_path.to_string();
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::Builder::new()
        .name("aura-embedder-load".into())
        .spawn(move || {
            let result = BgeTextEmbedder::new(&model_path, &tok_path).ok().map(Arc::new);
            let _ = tx.send(result);
        })
        .ok()?;
    match rx.recv_timeout(timeout) {
        Ok(Some(e)) => {
            #[cfg(target_os = "android")]
            log::info!(
                "[AURA_EMBED] embedder loaded ({:?} dim) from {}",
                e.dim(),
                embed_model_path
            );
            eprintln!(
                "[AURA_EMBED] embedder loaded ({:?} dim) from {}",
                e.dim(),
                embed_model_path
            );
            Some(e)
        }
        Ok(None) => {
            let err_msg = "embedder load failed (returned error)".to_string();
            #[cfg(target_os = "android")]
            log::error!("[AURA_EMBED] {err_msg}");
            eprintln!("[AURA_EMBED] WARN: {err_msg}");
            write_status(embed_model_path, &err_msg);
            None
        }
        Err(_) => {
            let err_msg = format!("embedder load timed out after {timeout:?}");
            #[cfg(target_os = "android")]
            log::error!("[AURA_EMBED] {err_msg}");
            eprintln!("[AURA_EMBED] WARN: {err_msg}");
            write_status(embed_model_path, &err_msg);
            None
        }
    }
}

fn log_file_size(path: &str, label: &str) {
    if let Ok(meta) = std::fs::metadata(path) {
        eprintln!("{label}: {path} = {} bytes", meta.len());
    } else {
        eprintln!("{label}: {path} (not found or unreadable)");
    }
}

fn write_status(embed_model_path: &str, msg: &str) {
    let err_file = std::path::Path::new(embed_model_path)
        .parent()
        .map(|p| p.join("aura_init_error.txt"));
    if let Some(path) = err_file {
        let _ = std::fs::write(path, msg);
    }
}
