pub(crate) mod output;
pub(crate) mod persona_retrieval;
pub(crate) mod reply;
pub(crate) mod turn;

use anyhow::Result;

use crate::frb_generated::StreamSink;
use crate::llama_engine::CANCEL_FLAG;

use super::{EngineMsg, TX};

pub(crate) use output::is_vision_query_prompt;
pub(crate) use turn::process_chat;

pub fn aura_cancel() -> bool {
    CANCEL_FLAG.store(true, std::sync::atomic::Ordering::Relaxed);
    true
}

pub fn aura_chat(sink: StreamSink<String>, prompt: String) -> Result<()> {
    match TX.get() {
        None => {
            let _ = sink.add("Engine not loaded.".to_string());
        }
        Some(tx) => {
            if tx.send(EngineMsg::Chat { prompt, sink }).is_err() {
                eprintln!("AURA_CHAT: channel closed");
            }
        }
    }
    Ok(())
}

pub fn aura_chat_chunked(sink: StreamSink<String>, chunks: Vec<String>) -> Result<()> {
    match TX.get() {
        None => Err(anyhow::anyhow!("engine not initialised")),
        Some(tx) => tx
            .send(EngineMsg::ChunkedChat { chunks, sink })
            .map_err(|e| anyhow::anyhow!("send error: {e}")),
    }
}

pub fn aura_prefill(partial: String) -> bool {
    TX.get()
        .is_some_and(|tx| tx.try_send(EngineMsg::Prefill { partial }).is_ok())
}

pub fn aura_inject(context: String) -> bool {
    TX.get()
        .is_some_and(|tx| tx.try_send(EngineMsg::Inject { _context: context }).is_ok())
}

pub fn aura_reset_state() -> bool {
    TX.get()
        .is_some_and(|tx| tx.try_send(EngineMsg::ResetState).is_ok())
}
