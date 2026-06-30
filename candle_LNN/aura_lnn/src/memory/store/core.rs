// store/core.rs - MemoryStore definition, constructor, and core connection helpers.
#![allow(unexpected_cfgs)]

use anyhow::Result;
use flutter_rust_bridge::frb;
use rusqlite::params;
use std::sync::Arc;

use crate::memory::notebook_file::NotebookMirror;
use crate::memory::store::facts::valid_profile_fact;
use crate::memory::store::pool::{ConnPool, PooledConn};
use crate::memory::store::utils::safe_context_memory;

#[frb(ignore)]
#[derive(Clone)]
pub struct MemoryStore {
    pub(crate) pool: Arc<ConnPool>,
    // Durable, uninstall-safe JSONL mirror (None when no writable durable
    // location exists). Cheap to clone — it's an Arc inside. Every durable
    // write (insert_turn/insert_fact/insert_summary/insert_memory_note)
    // appends a line here so AURA remembers you after a delete + reinstall.
    pub(crate) mirror: Option<Arc<NotebookMirror>>,
}

impl MemoryStore {
    pub fn open(db_path: &str) -> Result<Self> {
        let pool = ConnPool::new(db_path)?;
        // Open the durable mirror. db_path's parent is the app data dir, which
        // we pass as the last-resort fallback location (always writable).
        let app_data_dir = std::path::Path::new(db_path)
            .parent()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_else(|| ".".to_string());
        let mirror = NotebookMirror::open(&app_data_dir).map(Arc::new);
        // Use the pool's acquire to run schema init (which needs one connection).
        let store = Self {
            pool: Arc::new(pool),
            mirror,
        };

        // Schema init + seed — runs on a borrowed connection.
        {
            let conn = store.pool.acquire()?;
            conn.execute_batch(
                "
                CREATE TABLE IF NOT EXISTS turns (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session TEXT NOT NULL DEFAULT 'default',
                    speaker TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS summaries (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session TEXT NOT NULL DEFAULT 'default',
                    summary TEXT NOT NULL,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS facts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session TEXT NOT NULL DEFAULT 'default',
                    fact TEXT NOT NULL,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS vec_memory (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    content TEXT NOT NULL,
                    embedding BLOB,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS triggers (
                    trigger_id INTEGER PRIMARY KEY,
                    label TEXT NOT NULL,
                    engagement_score REAL NOT NULL DEFAULT 1.0,
                    last_fired INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS insights (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    kind TEXT NOT NULL,
                    content TEXT NOT NULL UNIQUE,
                    confidence REAL NOT NULL DEFAULT 0.5,
                    evidence_count INTEGER NOT NULL DEFAULT 0,
                    source TEXT NOT NULL DEFAULT 'chat',
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS proactive_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    trigger_id INTEGER NOT NULL,
                    label TEXT NOT NULL,
                    trigger_type TEXT NOT NULL DEFAULT 'bandit',
                    engaged INTEGER NOT NULL DEFAULT 0,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE TABLE IF NOT EXISTS memory_notes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL DEFAULT '',
                    content TEXT NOT NULL,
                    pinned INTEGER NOT NULL DEFAULT 0,
                    deleted INTEGER NOT NULL DEFAULT 0,
                    timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                );

                CREATE INDEX IF NOT EXISTS idx_turns_timestamp ON turns(timestamp);
                CREATE INDEX IF NOT EXISTS idx_summaries_timestamp ON summaries(timestamp);
                CREATE INDEX IF NOT EXISTS idx_facts_timestamp ON facts(timestamp);
                CREATE INDEX IF NOT EXISTS idx_vec_memory_timestamp ON vec_memory(timestamp);
                CREATE INDEX IF NOT EXISTS idx_memory_notes_deleted_pinned
                    ON memory_notes(deleted, pinned, timestamp);
                CREATE INDEX IF NOT EXISTS idx_proactive_log_timestamp ON proactive_log(timestamp);
                ",
            )?;

            // Migrate memory_notes to include deleted column
            let _ = conn.execute_batch(
                "ALTER TABLE memory_notes ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;",
            );

            // insight-confidence tracking columns, added in place so existing
            // user DBs migrate. (score deltas from engagement outcomes.)
            let _ = conn.execute_batch(
                "ALTER TABLE insights ADD COLUMN last_delta REAL NOT NULL DEFAULT 0.0;",
            );

            // RL bandit columns: track pulls + observed rewards so we can run a
            // softmax/epsilon-greedy policy with recency decay instead of the old
            // "score * random()" selection. Added with IF NOT EXISTS so existing
            // user DBs migrate in place.
            let _ = conn.execute_batch(
                "ALTER TABLE triggers ADD COLUMN n_shown INTEGER NOT NULL DEFAULT 0;
                 ALTER TABLE triggers ADD COLUMN n_engaged INTEGER NOT NULL DEFAULT 0;
                 ALTER TABLE triggers ADD COLUMN total_reward REAL NOT NULL DEFAULT 0.0;",
            );

            // Seed some initial triggers if empty
            let count: i64 = conn.query_row("SELECT COUNT(*) FROM triggers", [], |r| r.get(0))?;
            if count == 0 {
                let initial_triggers = vec![
                    (1, "How's your day going?"),
                    (2, "Did you learn anything interesting today?"),
                    (3, "I'm here if you need to brainstorm anything."),
                    (4, "Ready for our next project?"),
                    (5, "I've been thinking about our last conversation..."),
                    (6, "You seem busy today, anything I can help with?"),
                    (7, "By the way, I found something you might like."),
                    (8, "Shall we continue where we left off?"),
                ];
                // Wrap seed in a transaction so it's atomic.
                conn.execute_batch("BEGIN;")?;
                for (id, label) in initial_triggers {
                    let _ = conn.execute(
                        "INSERT INTO triggers (trigger_id, label) VALUES (?, ?)",
                        params![id, label],
                    );
                }
                conn.execute_batch("COMMIT;")?;
            }
            // Connection returns to pool on drop.
        }

        if let Err(e) = store.purge_trash_memory_rows() {
            eprintln!("[AURA_MEMORY] startup trash-memory purge failed: {e}");
        }

        Ok(store)
    }

    /// Create a standalone connection for a background worker (e.g. the
    /// store-embed thread). This connection is NOT pooled — the worker
    /// owns it for its entire lifetime, eliminating contention with the
    /// chat thread's pool connections.
    pub fn open_standalone(db_path: &str) -> Result<rusqlite::Connection> {
        crate::memory::store::pool::open_standalone(db_path)
    }

    /// Borrow a connection from the pool. Exposed so sibling modules (e.g.
    /// `vision::store`) that need bespoke SQL can run it through the same
    /// pooled/WAL-backed connection path as the rest of the store.
    pub fn acquire_conn(&self) -> Result<PooledConn> {
        self.pool.acquire()
    }

    pub fn purge_trash_memory_rows(&self) -> Result<usize> {
        let conn = self.pool.acquire()?;
        let mut deleted = 0usize;

        {
            let mut stmt = conn.prepare("SELECT id, fact FROM facts")?;
            let rows = stmt.query_map([], |row| {
                Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
            })?;
            let ids: Vec<i64> = rows
                .filter_map(|r| r.ok())
                .filter(|(_, fact)| !valid_profile_fact(fact))
                .map(|(id, _)| id)
                .collect();
            drop(stmt);
            for id in ids {
                deleted += conn.execute("DELETE FROM facts WHERE id = ?", params![id])?;
            }
        }

        {
            let mut stmt = conn.prepare("SELECT id, summary FROM summaries")?;
            let rows = stmt.query_map([], |row| {
                Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
            })?;
            let ids: Vec<i64> = rows
                .filter_map(|r| r.ok())
                .filter(|(_, summary)| !safe_context_memory(summary))
                .map(|(id, _)| id)
                .collect();
            drop(stmt);
            for id in ids {
                deleted += conn.execute("DELETE FROM summaries WHERE id = ?", params![id])?;
            }
            let extra_summary_ids: Vec<i64> = {
                let mut stmt = conn.prepare(
                    "SELECT id FROM summaries ORDER BY timestamp DESC, id DESC LIMIT -1 OFFSET 1",
                )?;
                let ids = stmt
                    .query_map([], |row| row.get::<_, i64>(0))?
                    .filter_map(|r| r.ok())
                    .collect();
                ids
            };
            for id in extra_summary_ids {
                deleted += conn.execute("DELETE FROM summaries WHERE id = ?", params![id])?;
            }
        }

        {
            let mut stmt = conn.prepare("SELECT id, speaker || ': ' || content FROM turns")?;
            let rows = stmt.query_map([], |row| {
                Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
            })?;
            let ids: Vec<i64> = rows
                .filter_map(|r| r.ok())
                .filter(|(_, turn)| !safe_context_memory(turn))
                .map(|(id, _)| id)
                .collect();
            drop(stmt);
            for id in ids {
                deleted += conn.execute("DELETE FROM turns WHERE id = ?", params![id])?;
            }
        }

        {
            let mut stmt = conn.prepare("SELECT id, content FROM vec_memory")?;
            let rows = stmt.query_map([], |row| {
                Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
            })?;
            let ids: Vec<i64> = rows
                .filter_map(|r| r.ok())
                .filter(|(_, content)| !safe_context_memory(content))
                .map(|(id, _)| id)
                .collect();
            drop(stmt);
            for id in ids {
                deleted += conn.execute("DELETE FROM vec_memory WHERE id = ?", params![id])?;
            }
        }

        {
            let mut stmt = conn.prepare(
                "SELECT id, title, content FROM memory_notes
                 WHERE content LIKE '%[Internal:%'
                    OR content LIKE '%RuntimeError%'
                    OR content LIKE '%ffmpeg version%'
                    OR content LIKE '%Traceback%'
                    OR lower(content) LIKE '%orion%'",
            )?;
            let ids: Vec<i64> = stmt
                .query_map([], |row| row.get::<_, i64>(0))?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for id in ids {
                deleted += conn.execute("DELETE FROM memory_notes WHERE id = ?", params![id])?;
            }
        }

        if deleted > 0 {
            eprintln!("[AURA_MEMORY] purged {deleted} trash memory row(s)");
        }
        Ok(deleted)
    }
}
