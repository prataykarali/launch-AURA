    use crate::engine::AuraEngine;
    use crate::frb_generated::StreamSink;
    use once_cell::sync::OnceCell;
    use std::sync::mpsc;
    use anyhow::Result;

    use crate::config::constants::THINKING_SENTINEL;

    enum EngineMsg {
        Chat { prompt: String, sink: StreamSink<String> },
        Inject { context: String },
        GetHistory { reply: std::sync::mpsc::SyncSender<String> },
        Prefill { partial: String },
ChunkedChat { chunks: Vec<String>, sink: StreamSink<String> },
    }

    static TX: OnceCell<mpsc::SyncSender<EngineMsg>> = OnceCell::new();
    pub fn aura_get_all_notebook_turns() -> String {
        match TX.get() {
            None => "[]".to_string(),
            Some(tx) => {
                let (reply_tx, reply_rx) = std::sync::mpsc::sync_channel(1);
                let _ = tx.try_send(EngineMsg::GetHistory { reply: reply_tx });
                reply_rx.recv_timeout(std::time::Duration::from_secs(3))
                    .unwrap_or_else(|_| "[]".to_string())
            }
        }
    }

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
        engine.infer_stream(&prompt, |tok| { 
            let _ = sink.add(tok); 
        });
        drop(sink);  // explicitly close AFTER inference is done
    }

    EngineMsg::Prefill { partial } => {
    engine.prefill(&partial);
}
EngineMsg::ChunkedChat { chunks, sink } => {
    for (i, chunk) in chunks.iter().enumerate() {
        eprintln!("AURA_CHUNK {}/{}: {} chars", i+1, chunks.len(), chunk.len());
        engine.infer_stream(chunk, |tok| { let _ = sink.add(tok); });
    }
    drop(sink);
}

        EngineMsg::Inject { context } => {
            let _ = engine.inject_context(&context);
        }
        EngineMsg::GetHistory { reply } => {
        let json = engine.store
            .get_all_turns_json()
            .unwrap_or_else(|_| "[]".to_string());
        let _ = reply.send(json);
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
                let _ = sink.add("❌ Engine not loaded.".to_string());
            }
            Some(tx) => {
                let _ = sink.add(THINKING_SENTINEL.to_string());
                // Use send() not try_send() — blocks until engine thread picks it up
                if tx.send(EngineMsg::Chat { prompt, sink }).is_err() {
                    eprintln!("AURA_CHAT: channel closed");
                }
            }
        }
        Ok(())
    }

    pub fn aura_prefill(partial: String) -> bool {
    if let Some(tx) = TX.get() {
        // Drain any stale prefills first — only latest matters
        tx.try_send(EngineMsg::Prefill { partial }).is_ok()
    } else {
        false
    }
}

pub fn aura_chat_chunked(sink: StreamSink<String>, chunks: Vec<String>) -> Result<()> {
    if let Some(tx) = TX.get() {
        let _ = sink.add("\x00__THINKING__\x00".to_string());
        tx.send(EngineMsg::ChunkedChat { chunks, sink })
            .map_err(|e| anyhow::anyhow!("send error: {e}"))?;
        Ok(())
    } else {
        Err(anyhow::anyhow!("engine not initialised"))
    }
}