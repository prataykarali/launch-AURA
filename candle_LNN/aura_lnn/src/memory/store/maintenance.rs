// store/maintenance.rs - Summarization, trimming, and store maintenance.

use anyhow::Result;
use rusqlite::params;

use crate::memory::store::utils::{safe_context_memory, strip_speaker_prefix};
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Number of stored turns — used by the mechanical summarization cap.
    pub fn turn_count(&self) -> Result<i64> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row("SELECT COUNT(*) FROM turns", [], |r| r.get(0))?;
        Ok(n)
    }

    /// Number of stored vector embeddings — used for runtime diagnostics.
    /// If this stays at 0 after multiple turns, the store-embed worker is broken.
    pub fn vec_memory_count(&self) -> Result<i64> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row("SELECT COUNT(*) FROM vec_memory", [], |r| r.get(0))?;
        Ok(n)
    }

    /// Compact the SQLite database: checkpoint/truncate the WAL and run VACUUM
    /// to reclaim free pages. This is only called during memory-pressure healing
    /// so the occasional pause is acceptable; it does not delete user data.
    pub fn compact_database(&self) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
        conn.execute_batch("VACUUM;")?;
        eprintln!("[AURA_MEMORY] Database compacted (WAL truncated + VACUUM).");
        Ok(())
    }

    /// Permanently remove memory notes that have been soft-deleted. They still
    /// occupy rows and embeddings until this runs.
    pub fn purge_soft_deleted_notes(&self) -> Result<usize> {
        let conn = self.pool.acquire()?;
        let n = conn.execute("DELETE FROM memory_notes WHERE deleted = 1", [])?;
        if n > 0 {
            eprintln!("[AURA_MEMORY] purged {n} soft-deleted note(s).");
        }
        Ok(n)
    }

    /// Keep only the `keep` most recent turns; older ones should already have
    /// been folded into a summary by summarize_history(). Prevents unbounded
    /// context growth.
    pub fn trim_turns(&self, keep: usize) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute(
            "DELETE FROM turns WHERE id NOT IN (
                SELECT id FROM turns ORDER BY id DESC LIMIT ?
            )",
            params![keep as i64],
        )?;
        Ok(())
    }

    /// Consolidate the oldest turns into a single summary row, then trim them.
    ///
    /// This is the missing summarization trigger referenced throughout the
    /// comments (`summarize_history()`) but never implemented. Without it the
    /// `turns` table grew without bound — the "mechanical cap every 6 turns"
    /// from the design doc silently did nothing, and `recent_turn_strings`
    /// kept re-injecting an ever-growing transcript.
    ///
    /// Strategy (cheap, no LLM call — matches the heuristic style of the rest
    /// of the memory subsystem):
    ///   1. Read the oldest `fold_n` turns as "speaker: content" pairs.
    ///   2. Compose a compact recap: keep each turn but cap it to a few words so
    ///      the summary stays well under a prompt-budget slice.
    ///   3. Insert it as a summary row (so get_recent_summaries_strings / the
    ///      notebook Summaries tab surface it).
    ///   4. trim_turns(keep) so the folded turns stop being re-injected.
    ///
    /// Idempotent-ish: it always folds from the oldest end, so repeated calls
    /// keep consolidating as new turns arrive. Returns the number of turns
    /// actually folded (0 if there were fewer than `fold_n + keep` turns).
    pub fn summarize_history(&self, keep: usize, fold_n: usize) -> Result<usize> {
        let total = self.turn_count()?;
        // Need strictly more than `keep` to fold anything; fold at most fold_n.
        if total <= keep as i64 || fold_n == 0 {
            return Ok(0);
        }
        let to_fold = (total - keep as i64).min(fold_n as i64).max(0) as usize;
        if to_fold == 0 {
            return Ok(0);
        }

        let conn = self.pool.acquire()?;
        // Oldest `to_fold` turns, in order.
        let mut stmt =
            conn.prepare("SELECT speaker, content FROM turns ORDER BY id ASC LIMIT ?")?;
        let rows = stmt.query_map([to_fold as i64], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let mut parts: Vec<String> = Vec::new();
        for (speaker, content) in rows.flatten() {
            let label = if speaker == "user" { "User" } else { "AURA" };
            // Cap each turn's contribution so the summary stays compact.
            let snippet: String = content.chars().take(120).collect();
            let snippet = snippet.trim();
            if !snippet.is_empty() {
                let contextual = format!("{label}: {snippet}");
                if safe_context_memory(&contextual) {
                    parts.push(contextual);
                }
            }
        }
        drop(stmt);

        if parts.is_empty() {
            return Ok(0);
        }

        let summary = format!("Earlier in this session — {}", parts.join(" | "));
        // Insert the summary through the normal path so it's also mirrored to
        // the durable notebook file.
        drop(conn);
        self.insert_summary(&summary)?;
        // Now drop the folded turns.
        self.trim_turns(keep)?;

        eprintln!(
            "[AURA_SUMMARY] folded {} turns into 1 summary (total was {})",
            to_fold, total
        );
        Ok(to_fold)
    }

    /// Replace the Summary tab contents with one compact recap of the last
    /// `pair_limit` user→assistant conversations. This keeps summaries useful
    /// and bounded: summaries are for recent conversation recap, not profile
    /// facts, visual observations, or raw transcript spam.
    pub fn replace_recent_conversation_summary(&self, pair_limit: usize) -> Result<()> {
        if pair_limit == 0 {
            return Ok(());
        }

        let conn = self.pool.acquire()?;
        let row_limit = (pair_limit * 2 + 4) as i64;
        let mut stmt = conn.prepare(
            "SELECT speaker, content FROM (
                SELECT id, speaker, content FROM turns ORDER BY id DESC LIMIT ?
             ) ORDER BY id ASC",
        )?;
        let rows = stmt.query_map([row_limit], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        let turns: Vec<(String, String)> = rows.filter_map(|r| r.ok()).collect();
        drop(stmt);

        let mut pairs: Vec<(String, String)> = Vec::new();
        let mut pending_user: Option<String> = None;
        for (speaker, content) in turns {
            let cleaned = strip_speaker_prefix(&content).trim().to_string();
            if cleaned.is_empty() {
                continue;
            }
            match speaker.as_str() {
                "user" => pending_user = Some(cleaned),
                "assistant" => {
                    if let Some(user) = pending_user.take() {
                        if safe_context_memory(&cleaned) {
                            pairs.push((user, cleaned));
                        }
                    }
                }
                _ => {}
            }
        }

        if pairs.is_empty() {
            return Ok(());
        }
        if pairs.len() > pair_limit {
            let drop_count = pairs.len() - pair_limit;
            pairs.drain(0..drop_count);
        }

        fn clip(text: &str, max_chars: usize) -> String {
            let trimmed = text.trim();
            if trimmed.chars().count() <= max_chars {
                return trimmed.to_string();
            }
            let mut out: String = trimmed.chars().take(max_chars).collect();
            if let Some(idx) = out.rfind(|c: char| c.is_whitespace()) {
                out.truncate(idx);
            }
            out.push_str("...");
            out
        }

        let mut lines = Vec::with_capacity(pairs.len() + 1);
        lines.push(format!("Last {} conversations:", pairs.len()));
        for (idx, (user, aura)) in pairs.iter().enumerate() {
            lines.push(format!(
                "{}. User: {} | AURA: {}",
                idx + 1,
                clip(user, 90),
                clip(aura, 110)
            ));
        }
        let summary = lines.join("\n");

        conn.execute("DELETE FROM summaries", [])?;
        conn.execute(
            "INSERT INTO summaries (session, summary) VALUES (?, ?)",
            params!["default", summary],
        )?;
        Ok(())
    }
}
