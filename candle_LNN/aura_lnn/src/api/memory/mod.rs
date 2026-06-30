use std::sync::mpsc;

use super::{EngineMsg, DB_PATH, TX};
use crate::memory::store::MemoryStore;

// ──────────────────────────────────────────────────────────────────────────
//  NOTEBOOK READS — direct read-only WAL connection (never blocks on the
//  engine worker). Previously these sent a message on the same single
//  worker channel as chat and blocked up to 2s; while the engine generated
//  (5–20s) they timed out and the notebook showed empty. A read-only WAL
//  connection reads concurrently with the writer — readers never block — so
//  the notebook always populates. Falls back to the worker path (also robust,
//  just slower) only if DB_PATH isn't set yet (very early startup).
// ──────────────────────────────────────────────────────────────────────────

pub(crate) fn with_db_path_or_empty<F: FnOnce(&str) -> String>(
    fallback_empty: &str,
    f: F,
) -> String {
    match DB_PATH.get() {
        Some(path) => f(path),
        None => fallback_empty.to_string(),
    }
}

fn database_file_empty(path: &str) -> bool {
    use std::fs;
    match fs::metadata(path) {
        Ok(meta) => meta.len() == 0,
        Err(_) => true, // Treat missing file as empty
    }
}

pub fn aura_get_all_notebook_turns() -> String {
    with_db_path_or_empty("[]", |_path| {
        let rows = MemoryStore::read_notebook_turns_ro(_path);
        if !rows.is_empty() {
            serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
        } else if database_file_empty(_path) {
            "[]".to_string()
        } else {
            eprintln!("[AURA_MEMORY] DB file exists but no data accessible. Retrying worker...");
            worker_get_history().unwrap_or_else(|| "[]".to_string())
        }
    })
}

pub fn aura_get_all_summaries_json() -> String {
    with_db_path_or_empty("[]", |_path| {
        let rows = MemoryStore::read_notebook_summaries_ro(_path);
        if !rows.is_empty() {
            serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
        } else {
            worker_get_summaries().unwrap_or_else(|| "[]".to_string())
        }
    })
}

pub fn aura_get_all_facts_json() -> String {
    with_db_path_or_empty("[]", |_path| {
        let rows = MemoryStore::read_notebook_facts_ro(_path);
        if !rows.is_empty() {
            serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
        } else {
            worker_get_facts().unwrap_or_else(|| "[]".to_string())
        }
    })
}

// ──────────────────────────────────────────────────────────────────────────
//  NEW NOTEBOOK SURFACES
// ──────────────────────────────────────────────────────────────────────────

/// Notebook "Insights" tab — durable synthesized understandings about the
/// user, ordered by confidence. `{id, kind, content, confidence,
/// evidence_count, source, timestamp}`.
pub fn aura_get_notebook_insights_json() -> String {
    with_db_path_or_empty("[]", |path| {
        let rows = MemoryStore::read_notebook_insights_ro(path);
        serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
    })
}

/// Notebook "Insights" tab — the RL proactive timeline (last 100 events).
/// `{id, trigger_id, label, trigger_type, engaged, timestamp}`.
pub fn aura_get_notebook_proactive_log_json() -> String {
    with_db_path_or_empty("[]", |path| {
        let rows = MemoryStore::read_proactive_log_ro(path, 100);
        serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
    })
}

/// Notebook memory notes — user/pinned notes that are ALSO embedded into
/// vec_memory so RAG retrieves them forever. `{id, title, content, pinned,
/// timestamp}`.
pub fn aura_get_memory_notes_json() -> String {
    with_db_path_or_empty("[]", |path| {
        let rows = MemoryStore::read_memory_notes_ro(path);
        serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
    })
}

/// Semantic recall: embed the query and return the top-`limit` most relevant
/// memory strings from vec_memory. Used by the notebook "Related memories"
/// expandable. Falls back to empty string if the embedder isn't ready.
pub fn aura_search_relevant(query: String, limit: i64) -> String {
    let tx = TX.get();
    if tx.is_none() {
        return "[]".to_string();
    }
    let (reply_tx, reply_rx) = mpsc::sync_channel::<String>(1);
    if let Some(tx) = tx {
        let _ = tx.try_send(EngineMsg::SearchRelevant {
            query,
            limit: limit.max(0) as usize,
            reply: reply_tx,
        });
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(3))
            .unwrap_or_else(|_| "[]".to_string())
    } else {
        "[]".to_string()
    }
}

pub fn aura_get_overlay_config() -> String {
    crate::memory::android_overlay::aura_get_overlay_config()
}

// ──────────────────────────────────────────────────────────────────────────
//  Original worker-routed reads (kept as fallbacks for the notebook reads,
//  and as the primary path for everything that genuinely needs the worker).
// ──────────────────────────────────────────────────────────────────────────

fn worker_get_history() -> Option<String> {
    let tx = TX.get()?;
    let (reply_tx, reply_rx) = mpsc::sync_channel(1);
    tx.try_send(EngineMsg::GetHistory { reply: reply_tx })
        .ok()?;
    reply_rx
        .recv_timeout(std::time::Duration::from_secs(2))
        .ok()
}

fn worker_get_summaries() -> Option<String> {
    let tx = TX.get()?;
    let (reply_tx, reply_rx) = mpsc::sync_channel(1);
    tx.try_send(EngineMsg::GetSummaries { reply: reply_tx })
        .ok()?;
    reply_rx
        .recv_timeout(std::time::Duration::from_secs(2))
        .ok()
}

fn worker_get_facts() -> Option<String> {
    let tx = TX.get()?;
    let (reply_tx, reply_rx) = mpsc::sync_channel(1);
    tx.try_send(EngineMsg::GetFacts { reply: reply_tx }).ok()?;
    reply_rx
        .recv_timeout(std::time::Duration::from_secs(2))
        .ok()
}

/// Ask the worker to check current system memory pressure and run the safe
/// auto-healer if needed. Returns a JSON status string with `pressure`,
/// `available_gb`, `total_gb`, `used_gb`, `did_heal`, and a friendly `message`.
/// The Flutter side can call this on a timer or whenever the OS reports low
/// memory, and show AURA's message instead of a generic "please close something
/// memory full" toast.
pub fn aura_check_memory_health() -> String {
    let tx = TX.get();
    if tx.is_none() {
        return crate::memory_health::memory_status_json();
    }
    let (reply_tx, reply_rx) = mpsc::sync_channel::<String>(1);
    if let Some(tx) = tx {
        if tx
            .try_send(EngineMsg::HealMemory {
                reply: Some(reply_tx),
            })
            .is_ok()
        {
            return reply_rx
                .recv_timeout(std::time::Duration::from_secs(5))
                .unwrap_or_else(|e| {
                    eprintln!("[AURA_MEMORY] HealMemory reply timed out: {e}");
                    crate::memory_health::memory_status_json()
                });
        }
    }
    crate::memory_health::memory_status_json()
}

pub mod notes;
pub mod proactive;

pub use notes::{
    aura_add_memory_note, aura_delete_memory_note, aura_delete_memory_note_permanently,
    aura_recover_memory_note, aura_update_memory_note,
};
pub use proactive::{
    aura_check_proactive, aura_get_buffer_status, aura_get_proactive_context, aura_log_proactive,
    aura_record_engagement,
};
