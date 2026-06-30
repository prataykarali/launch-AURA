// store/inserts.rs - Durable writes for turns, summaries, and facts.

use anyhow::Result;
use rusqlite::params;

use crate::memory::notebook_file::NotebookRecord;
use crate::memory::store::facts::valid_profile_fact;
use crate::memory::store::utils::{cap_chars, now_ts, safe_context_memory, strip_speaker_prefix};
use crate::memory::store::MemoryStore;

impl MemoryStore {
    pub fn insert_turn(&self, speaker: &str, content: &str) -> Result<()> {
        if content.trim_start().starts_with("[Internal:") {
            return Ok(());
        }
        // Normalize before storage so we never persist — and therefore never
        // re-inject — the leaked "AURA:" speaker label. The chat model latches
        // onto patterns it sees in its own prior turns, so a single stored
        // "AURA:" row teaches it to prefix every reply with "AURA:". Trim
        // it once, at the source.
        let cleaned = cap_chars(
            &strip_speaker_prefix(content),
            crate::memory::store::MAX_TURN_CHARS,
        );
        if cleaned.is_empty() || !safe_context_memory(&format!("{speaker}: {cleaned}")) {
            return Ok(());
        }
        let conn = self.pool.acquire()?;
        conn.execute(
            "INSERT INTO turns (session, speaker, content) VALUES (?, ?, ?)",
            params!["default", speaker, &cleaned],
        )?;
        drop(conn);
        // Mirror to the durable, uninstall-safe notebook file. Best-effort: a
        // mirror write failure must NOT fail the turn insert (the DB row is the
        // source of truth for the live session; the mirror only needs to be
        // "good enough" to re-seed after a reinstall).
        self.mirror_append(NotebookRecord {
            kind: "turn".to_string(),
            speaker: Some(speaker.to_string()),
            content: cleaned.clone(),
            title: None,
            pinned: None,
            deleted: None,
            ts: now_ts(),
        });
        Ok(())
    }

    pub fn insert_summary(&self, summary: &str) -> Result<()> {
        if summary.trim_start().starts_with("[Internal:") {
            return Ok(());
        }
        let summary = cap_chars(summary.trim(), crate::memory::store::MAX_SUMMARY_CHARS);
        if summary.is_empty() || !safe_context_memory(&summary) {
            return Ok(());
        }
        let conn = self.pool.acquire()?;
        conn.execute(
            "INSERT INTO summaries (session, summary) VALUES (?, ?)",
            params!["default", &summary],
        )?;
        drop(conn);
        self.mirror_append(NotebookRecord {
            kind: "summary".to_string(),
            speaker: None,
            content: summary,
            title: None,
            pinned: None,
            deleted: None,
            ts: now_ts(),
        });
        Ok(())
    }

    pub fn insert_fact(&self, fact: &str) -> Result<()> {
        if fact.trim_start().starts_with("[Internal:") {
            return Ok(());
        }
        let fact = cap_chars(fact.trim(), crate::memory::store::MAX_FACT_CHARS);
        if !valid_profile_fact(&fact) {
            return Ok(());
        }
        let conn = self.pool.acquire()?;
        conn.execute(
            "INSERT INTO facts (session, fact) VALUES (?, ?)",
            params!["default", &fact],
        )?;
        drop(conn);
        self.mirror_append(NotebookRecord {
            kind: "fact".to_string(),
            speaker: None,
            content: fact,
            title: None,
            pinned: None,
            deleted: None,
            ts: now_ts(),
        });
        Ok(())
    }

    pub fn delete_name_facts(&self) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute("DELETE FROM facts WHERE fact LIKE 'User''s name is %'", [])?;
        Ok(())
    }

    pub fn delete_facts_matching_pattern(&self, pattern: &str) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute("DELETE FROM facts WHERE fact LIKE ?", [pattern])?;
        Ok(())
    }
}
