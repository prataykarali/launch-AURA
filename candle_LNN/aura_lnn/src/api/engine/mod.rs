use std::sync::mpsc;

use super::config::configure_rayon_threads;
use super::{EngineMsg, DB_PATH, MODEL_DIR, TX};

mod init;
mod paths;
mod worker;
mod worker_handlers;
mod worker_loop;

pub fn aura_get_available_backends() -> String {
    let backends = crate::device_backend::DeviceBackend::available();
    serde_json::to_string(&backends).unwrap_or_else(|_| "[]".to_string())
}

pub fn aura_set_backend(backend_name: String) -> bool {
    eprintln!("[AURA_ENGINE] Requested backend change to: {backend_name}");
    true
}

pub fn aura_set_threads(threads: i32) -> bool {
    eprintln!("[AURA_ENGINE] Requested thread count: {threads}");
    true
}

pub fn aura_set_context_size(n_ctx: u32) -> bool {
    eprintln!("[AURA_ENGINE] Requested context size: {n_ctx}");
    true
}

pub fn aura_clear_memory() -> bool {
    eprintln!("[AURA_ENGINE] Clearing memory...");
    if let Some(db_path) = DB_PATH.get() {
        for path in [
            db_path.to_string(),
            format!("{db_path}-wal"),
            format!("{db_path}-shm"),
        ] {
            let _ = std::fs::remove_file(path);
        }

        if let Some(parent) = std::path::Path::new(db_path).parent() {
            let _ = std::fs::remove_file(parent.join("notebook.jsonl"));
        }
        if let Ok(p) = std::env::var("AURA_NOTEBOOK_PATH") {
            if !p.trim().is_empty() {
                let _ = std::fs::remove_file(p);
            }
        }
        if let Ok(xdg) = std::env::var("XDG_DATA_HOME") {
            if !xdg.trim().is_empty() {
                let _ = std::fs::remove_file(
                    std::path::Path::new(&xdg)
                        .join("AURA")
                        .join("notebook.jsonl"),
                );
            }
        }
        if let Ok(home) = std::env::var("HOME") {
            if !home.trim().is_empty() {
                let _ = std::fs::remove_file(
                    std::path::Path::new(&home)
                        .join(".local/share/AURA")
                        .join("notebook.jsonl"),
                );
            }
        }
        return true;
    }
    false
}

pub async fn aura_init(
    model_path: String,
    tokenizer_path: String,
    embed_model_path: String,
    embed_tok_path: String,
) -> bool {
    configure_rayon_threads();
    eprintln!(
        "[AURA_PERF] smooth performance policy: {}",
        super::config::smooth_performance_label()
    );

    if TX.get().is_some() {
        return true;
    }

    let (tx, rx) = mpsc::sync_channel::<EngineMsg>(20);

    let model_dir = std::path::Path::new(&model_path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| ".".to_string());

    let db_path = paths::resolve_db_path(&model_dir, &tokenizer_path);
    let _ = DB_PATH.set(db_path.clone());
    let _ = MODEL_DIR.set(model_dir.clone());

    let (ready_tx, ready_rx) = mpsc::sync_channel::<bool>(1);

    worker::spawn_worker(
        model_path,
        rx,
        ready_tx,
        db_path,
        embed_model_path,
        embed_tok_path,
    );

    match ready_rx.recv_timeout(std::time::Duration::from_secs(300)) {
        Ok(true) => {
            eprintln!("[AURA_INIT] Engine ready, releasing loading screen.");
            let tx_for_healer = tx.clone();
            let ok = TX.set(tx).is_ok() || TX.get().is_some();
            if ok {
                crate::memory_health::spawn_background_healer(move |msg| {
                    let _ = tx_for_healer.send(msg);
                });
            }
            ok
        }
        Ok(false) => {
            eprintln!("[AURA_INIT] Engine failed to load; chat channel not installed.");
            false
        }
        Err(e) => {
            eprintln!("[AURA_INIT] Timed out waiting for engine readiness: {e}");
            false
        }
    }
}
