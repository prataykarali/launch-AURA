use flutter_rust_bridge::frb;
use crate::frb_generated::StreamSink;
use once_cell::sync::OnceCell;
use std::sync::Mutex;
use crate::engine::AuraEngine;

static ENGINE: OnceCell<Mutex<AuraEngine>> = OnceCell::new();

// NO #[frb(sync)] — runs on FRB worker thread, not main thread
pub fn aura_init(model_path: String, tokenizer_path: String) -> bool {
    if ENGINE.get().is_some() { return true; }

    match AuraEngine::load(&model_path, &tokenizer_path) {
        Ok(engine) => {
            eprintln!("AURA_INIT_OK: model loaded successfully");
            ENGINE.set(Mutex::new(engine)).is_ok()
        }
        Err(e) => {
            eprintln!("AURA_INIT_FAILED: {e:?}");
            false
        }
    }
}

pub fn aura_chat(sink: StreamSink<String>, prompt: String) -> anyhow::Result<()> {
    if ENGINE.get().is_none() {
        let _ = sink.add("❌ AURA engine not loaded.".to_string());
        return Ok(());
    }
    std::thread::spawn(move || {
        if let Some(binding) = ENGINE.get() {
            if let Ok(mut eng) = binding.lock() {
                eng.infer_stream(&prompt, |token| {
                    let _ = sink.add(token);
                });
            }
        }
    });
    Ok(())
}