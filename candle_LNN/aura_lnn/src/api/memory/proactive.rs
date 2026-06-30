use std::sync::mpsc;

use super::{EngineMsg, TX};

pub fn aura_get_buffer_status() -> String {
    match TX.get() {
        None => r#"{"intercept_needed":false,"message":"","turns":0,"tokens":0}"#.to_string(),
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::BufferStatus { reply: reply_tx });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or_else(|_| {
                    r#"{"intercept_needed":false,"message":"","turns":0,"tokens":0}"#.to_string()
                })
        }
    }
}

pub fn aura_check_proactive() -> String {
    match TX.get() {
        None => String::new(),
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::CheckScheduler { reply: reply_tx });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .ok()
                .flatten()
                .unwrap_or_default()
        }
    }
}

/// Compact recall block (facts / recent summary / recent turns / insights) for
/// proactive prompts. Returns an empty string when there is nothing to recall.
pub fn aura_get_proactive_context() -> String {
    match TX.get() {
        None => String::new(),
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::GetProactiveContext { reply: reply_tx });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or_default()
        }
    }
}

pub fn aura_record_engagement(trigger_id: i64, engaged: bool) -> bool {
    match TX.get() {
        None => false,
        Some(tx) => {
            let (reply_tx, reply_rx) = mpsc::sync_channel(1);
            let _ = tx.try_send(EngineMsg::RecordEngagement {
                trigger_id,
                engaged,
                reply: reply_tx,
            });
            reply_rx
                .recv_timeout(std::time::Duration::from_secs(2))
                .unwrap_or(false)
        }
    }
}

/// Record a proactive event in the RL timeline (visible in the notebook).
/// Called from the Dart scheduler/brain whenever a trigger fires + when its
/// outcome (engaged/ignored) is known. `trigger_type` is bandit/clock/idle/debug.
pub fn aura_log_proactive(
    trigger_id: i64,
    label: String,
    trigger_type: String,
    engaged: bool,
) -> bool {
    let (reply_tx, reply_rx) = mpsc::sync_channel::<bool>(1);
    if let Some(tx) = TX.get() {
        let _ = tx.try_send(EngineMsg::LogProactive {
            trigger_id,
            label,
            trigger_type,
            engaged,
            reply: reply_tx,
        });
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(2))
            .unwrap_or(false)
    } else {
        false
    }
}
