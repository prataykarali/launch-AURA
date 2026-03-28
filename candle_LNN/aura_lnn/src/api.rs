use flutter_rust_bridge::frb;
use crate::frb_generated::StreamSink;
use once_cell::sync::OnceCell;
use std::sync::mpsc;
use crate::engine::AuraEngine;

type InferRequest = (String, StreamSink<String>);

static TX: OnceCell<mpsc::SyncSender<InferRequest>> = OnceCell::new();

pub fn aura_init(model_path: String, tokenizer_path: String) -> bool {
    if TX.get().is_some() { return true; }

    match AuraEngine::load(&model_path, &tokenizer_path) {
        Ok(mut engine) => {
            eprintln!("AURA_INIT_OK");

            // Channel capacity 4: enough headroom so the inference thread
            // never blocks waiting for Dart to consume, but small enough
            // that we don't queue stale requests.
            let (tx, rx) = mpsc::sync_channel::<InferRequest>(4);

            std::thread::spawn(move || {
                while let Ok((prompt, sink)) = rx.recv() {
                    // Send EVERY token immediately — no batching.
                    // Flutter's drain queue handles the pacing on the Dart side.
                    // Each token is typically 1-4 chars; sending raw gives
                    // Flutter the finest granularity to animate char-by-char.
                    engine.infer_stream(&prompt, |token: String| {
                        let _ = sink.add(token);
                    });
                    // sink drop signals stream end to Dart automatically
                }
            });

            TX.set(tx).is_ok()
        }
        Err(e) => {
            eprintln!("AURA_INIT_FAILED: {e:?}");
            false
        }
    }
}

pub fn aura_chat(sink: StreamSink<String>, prompt: String) -> anyhow::Result<()> {
    match TX.get() {
        None => {
            let _ = sink.add("❌ AURA engine not loaded.".to_string());
        }
        Some(tx) => {
            match tx.try_send((prompt, sink)) {
                Ok(_) => {}
                Err(mpsc::TrySendError::Full(_)) => {
                    eprintln!("AURA: inference queue full");
                }
                Err(mpsc::TrySendError::Disconnected(_)) => {
                    eprintln!("AURA: inference thread died");
                }
            }
        }
    }
    Ok(())
}