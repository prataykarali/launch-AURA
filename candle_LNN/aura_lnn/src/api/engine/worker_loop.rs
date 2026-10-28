use std::sync::mpsc;

use crate::api::EngineMsg;
use crate::plugins::PluginRegistry;

pub(crate) fn run_worker(
    model_path: String,
    rx: mpsc::Receiver<EngineMsg>,
    ready_tx: mpsc::SyncSender<bool>,
    db_path: String,
    embed_model_path: String,
    embed_tok_path: String,
) {
    let (mut engine_opt, memory_store) =
        super::init::initialize_engine(&model_path, &embed_model_path, &embed_tok_path, &db_path);

    crate::api::stt::aura_stt_init();

    // Initialize plugin registry. Plugins are loaded here.
    // Future plugins register themselves in this block.
    let plugin_registry = PluginRegistry::new();
    {
        // Built-in plugins register here, in priority order.
        plugin_registry.register(Box::new(crate::plugins::ScreenOcrPlugin::new()));

        let embedder = engine_opt.as_ref().and_then(|e| e.embedder());
        let ctx = crate::plugins::PluginContext {
            memory_store: memory_store.clone(),
            embedder,
            config: crate::plugins::PluginConfig::detect(),
        };
        plugin_registry.init_all(&ctx);
    }

    eprintln!(
        "[AURA_WORKER] Ready ({} plugins loaded)",
        plugin_registry.count()
    );
    let _ = ready_tx.send(engine_opt.is_some() && memory_store.is_some());

    let mut prefilled_memories: Option<Vec<String>> = None;
    let mut vision_gate = crate::vision::VisionGate::new(5, 0.45, 0.5);

    while let Ok(msg) = rx.recv() {
        let engine = match &mut engine_opt {
            Some(e) => e,
            None => {
                eprintln!("[AURA_WORKER_ERR] Message received but engine not loaded.");
                match msg {
                    EngineMsg::Chat { sink, .. } | EngineMsg::ChunkedChat { sink, .. } => {
                        let _ = sink.add(
                            "Error: LLM Engine not loaded. Check console for details.".to_string(),
                        );
                        drop(sink);
                    }
                    _ => {}
                }
                continue;
            }
        };

        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            super::worker_handlers::dispatch_message(
                engine,
                &memory_store,
                &mut prefilled_memories,
                &mut vision_gate,
                msg,
                &plugin_registry,
            );
        }));
    }

    plugin_registry.shutdown_all();
}
