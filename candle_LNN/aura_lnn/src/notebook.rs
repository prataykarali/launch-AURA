use anyhow::Result;
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};

/// Global notebook handle so api.rs can read turns without going through the engine channel.
pub static GLOBAL_NOTEBOOK: OnceCell<ConvNotebook> = OnceCell::new();

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ConvTurn {
    pub user: String,
    pub aura: String,
    pub ts:   i64,
}

pub struct ConvNotebook {
    db: sled::Db,
}

impl ConvNotebook {
    pub fn open(model_path: &str) -> Result<Self> {
        let dir = std::path::Path::new(model_path)
            .parent()
            .unwrap_or(std::path::Path::new("."));
        let db_path = dir.join("aura_notebook.sleddb");
        let db = sled::open(&db_path)?;
        eprintln!("Notebook: opened at {:?}", db_path);
        Ok(Self { db })
    }

    /// Write a conversation turn and flush to disk immediately.
    /// FIX N2: flush() guarantees the turn survives a crash before the OS
    ///         flushes its own page cache.
    pub fn write_turn(&self, user: &str, aura: &str) -> Result<()> {
        let turn = ConvTurn {
            user: user.to_string(),
            aura: aura.to_string(),
            ts:   chrono::Utc::now().timestamp(),
        };
        let id  = self.db.generate_id()?;
        let key = format!("turn:{:016}", id);
        let val = serde_json::to_vec(&turn)?;
        self.db.insert(key.as_bytes(), val)?;
        // FIX N2: ensure the write is durable before we return
        self.db.flush()?;
        eprintln!("Notebook: wrote turn {}", id);
        Ok(())
    }

    /// Return the `n` most recent turns in **chronological** order.
    /// FIX N1: sled scan order is insertion-order (monotonic ID), which
    ///         matches time order because we use generate_id().  But we
    ///         sort by `ts` anyway so a clock-skew or a restored snapshot
    ///         can never shuffle turns.
    pub fn read_recent(&self, n: usize) -> Vec<ConvTurn> {
        let mut turns: Vec<ConvTurn> = self
            .db
            .scan_prefix(b"turn:")
            .filter_map(|r| r.ok())
            .filter_map(|(_, v)| serde_json::from_slice(&v).ok())
            .collect();

        // FIX N1: always sort chronologically before slicing
        turns.sort_by_key(|t| t.ts);

        let start = turns.len().saturating_sub(n);
        turns.split_off(start)
    }

    pub fn all_turns(&self) -> Vec<ConvTurn> {
        let mut turns: Vec<ConvTurn> = self
            .db
            .scan_prefix(b"turn:")
            .filter_map(|r| r.ok())
            .filter_map(|(_, v)| serde_json::from_slice(&v).ok())
            .collect();
        turns.sort_by_key(|t| t.ts);
        turns
    }

    pub fn load_sys_prompt(&self) -> Option<String> {
        self.db
            .get(b"sys_prompt")
            .ok()
            .flatten()
            .and_then(|v| String::from_utf8(v.to_vec()).ok())
    }

    pub fn save_sys_prompt(&self, prompt: &str) -> Result<()> {
        self.db.insert(b"sys_prompt", prompt.as_bytes())?;
        self.db.flush()?;
        Ok(())
    }
}