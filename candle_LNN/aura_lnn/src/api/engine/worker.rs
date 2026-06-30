use std::sync::mpsc;

use crate::api::EngineMsg;

pub(crate) fn spawn_worker(
    model_path: String,
    rx: mpsc::Receiver<EngineMsg>,
    ready_tx: mpsc::SyncSender<bool>,
    db_path: String,
    embed_model_path: String,
    embed_tok_path: String,
) {
    std::thread::Builder::new()
        .name("aura-engine-worker".into())
        .stack_size(32 * 1024 * 1024)
        .spawn(move || {
            super::worker_loop::run_worker(
                model_path,
                rx,
                ready_tx,
                db_path,
                embed_model_path,
                embed_tok_path,
            );
        })
        .expect("Failed to spawn worker thread");
}
