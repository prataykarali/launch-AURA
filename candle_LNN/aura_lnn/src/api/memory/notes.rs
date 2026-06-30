use std::sync::mpsc;

use super::{EngineMsg, TX};

pub fn aura_add_memory_note(title: String, content: String, pinned: bool) -> i64 {
    let (reply_tx, reply_rx) = mpsc::sync_channel::<i64>(1);
    if let Some(tx) = TX.get() {
        let _ = tx.try_send(EngineMsg::AddMemoryNote {
            title,
            content,
            pinned,
            reply: reply_tx,
        });
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(3))
            .unwrap_or(-1)
    } else {
        -1
    }
}

pub fn aura_delete_memory_note(id: i64) -> bool {
    let (reply_tx, reply_rx) = mpsc::sync_channel::<bool>(1);
    if let Some(tx) = TX.get() {
        let _ = tx.try_send(EngineMsg::DeleteMemoryNote {
            id,
            reply: reply_tx,
        });
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(2))
            .unwrap_or(false)
    } else {
        false
    }
}

pub fn aura_update_memory_note(
    id: i64,
    title: String,
    content: String,
    pinned: bool,
    deleted: bool,
) -> bool {
    match TX.get() {
        None => false,
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::UpdateMemoryNote {
                id,
                title,
                content,
                pinned,
                deleted,
                reply: reply_tx,
            });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or(false)
        }
    }
}

pub fn aura_recover_memory_note(id: i64) -> bool {
    match TX.get() {
        None => false,
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::RecoverMemoryNote {
                id,
                reply: reply_tx,
            });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or(false)
        }
    }
}

pub fn aura_delete_memory_note_permanently(id: i64) -> bool {
    match TX.get() {
        None => false,
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::DeleteMemoryNotePermanently {
                id,
                reply: reply_tx,
            });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or(false)
        }
    }
}
