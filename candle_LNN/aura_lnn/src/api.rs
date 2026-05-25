use crate::engine::AuraEngine;
use crate::frb_generated::StreamSink;
use once_cell::sync::OnceCell;
use std::sync::mpsc;
use anyhow::Result;

use crate::config::constants::THINKING_SENTINEL;

enum EngineMsg {
    Chat { prompt: String, sink: StreamSink<String> },
    Inject { context: String },
}

static TX: OnceCell<mpsc::SyncSender<EngineMsg>> = OnceCell::new();
pub fn aura_init(model_path: String, tokenizer_path: String) -> bool {
    // CRITICAL FIX 1: Only use 2 threads for AI to stop UI lag
    let _ = rayon::ThreadPoolBuilder::new().num_threads(2).build_global();

    // Remove `crate::` here, just use TX directly
    if TX.get().is_some() { return true; }
    
    let mut engine = match crate::engine::AuraEngine::load(&model_path, &tokenizer_path) {
        Ok(e)  => e,
        Err(e) => { eprintln!("AURA_INIT_FAILED: {e:?}"); return false; }
    };
    
    // Remove `crate::` from EngineMsg
    let (tx, rx) = std::sync::mpsc::sync_channel::<EngineMsg>(10);
    
    // Remove `crate::` here
    if TX.set(tx).is_err() { 
        return false; 
    }
    
    std::thread::spawn(move || {
        // Warmup runs silently in the background
        if let Err(e) = engine.warmup() {
            eprintln!("Warmup error: {}", e);
        }
        
        while let Ok(msg) = rx.recv() {
            match msg {
                // Remove `crate::` from EngineMsg
                EngineMsg::Chat { prompt, sink } => {
                    engine.infer_stream(&prompt, |tok| { let _ = sink.add(tok); });
                }
                EngineMsg::Inject { context } => {
                    let _ = engine.inject_context(&context);
                }
            }
        }
    });
    
    true
}

pub fn aura_inject(context: String) -> bool {
    match TX.get() {
        Some(tx) => tx.try_send(EngineMsg::Inject { context }).is_ok(),
        None     => false,
    }
}
pub fn aura_chat(sink: StreamSink<String>, prompt: String) -> Result<()> {
    match TX.get() {
        None => { 
            // Use .map_err to convert the bridge error into something anyhow understands
            sink.add("\u{274C} Engine not loaded.".to_string())
                .map_err(|e| anyhow::anyhow!("Stream error: {:?}", e))?; 
        }
        Some(tx) => {
            sink.add(THINKING_SENTINEL.to_string())
                .map_err(|e| anyhow::anyhow!("Stream error: {:?}", e))?;
                
            let _ = tx.try_send(EngineMsg::Chat { prompt, sink });
        }
    }
    Ok(())
}