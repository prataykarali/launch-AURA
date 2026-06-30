// store/mirror.rs - Durable notebook mirror chokepoints and re-seed dedup.
//
// The mirror is the uninstall-safe JSONL transcript (see notebook_file.rs).
// These helpers are the chokepoints: every durable write calls
// mirror_append(), and the engine calls mirror_path() + reseed_from_file()
// on a fresh install. The dedup predicates (turn_exists / summary_exists /
// note_exists) make re-seed idempotent.

use anyhow::Result;
use rusqlite::params;
use std::path::PathBuf;

use crate::memory::notebook_file::NotebookRecord;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Best-effort append to the durable mirror. Logs on failure; never panics
    /// or returns Err — a mirror miss only affects post-reinstall recall, not
    /// the live session.
    pub(crate) fn mirror_append(&self, record: NotebookRecord) {
        if let Some(mirror) = &self.mirror {
            if let Err(e) = mirror.append(record) {
                eprintln!("[AURA_NOTEBOOK] mirror append failed: {e}");
            }
        }
    }

    /// Path of the durable mirror file (for re-seed + diagnostics). None when
    /// no mirror is open.
    pub fn mirror_path(&self) -> Option<PathBuf> {
        self.mirror.as_ref().map(|m| m.path_of())
    }

    /// True if a turn with this (speaker, content) already exists. Used by
    /// re-seed to avoid replaying turns that are already in the DB.
    pub fn turn_exists(&self, speaker: &str, content: &str) -> Result<bool> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row(
            "SELECT COUNT(*) FROM turns WHERE speaker = ? AND content = ?",
            params![speaker, content],
            |r| r.get(0),
        )?;
        Ok(n > 0)
    }

    /// True if a summary with this content already exists (case-insensitive).
    pub fn summary_exists(&self, summary: &str) -> Result<bool> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row(
            "SELECT COUNT(*) FROM summaries WHERE lower(summary) = lower(?)",
            params![summary],
            |r| r.get(0),
        )?;
        Ok(n > 0)
    }

    /// True if a memory note with this (title, content) already exists.
    pub fn note_exists(&self, title: &str, content: &str) -> Result<bool> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row(
            "SELECT COUNT(*) FROM memory_notes WHERE content = ? AND (title = ? OR (title = '' AND ? = ''))",
            params![content, title, title],
            |r| r.get(0),
        )?;
        Ok(n > 0)
    }
}
