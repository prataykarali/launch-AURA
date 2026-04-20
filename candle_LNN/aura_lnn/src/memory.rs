// src/memory.rs
//
// AURA's persistent memory brain — Sled-backed, three-tier.
//
// ┌──────────────┬───────────────┬──────────────────────────┐
// │  Tier        │  TTL          │  Example                 │
// ├──────────────┼───────────────┼──────────────────────────┤
// │  permanent   │  forever      │  name, job, prefs        │
// │  cache       │  30 days      │  mood, recent topic      │
// │  forgotten   │  tombstone    │  user said "forget"      │
// └──────────────┴───────────────┴──────────────────────────┘
//
// Key format in Sled:
//   "mem:perm:{key}"    → MemoryEntry (permanent)
//   "mem:cache:{key}"   → MemoryEntry (expires)
//   "mem:forget:{key}"  → tombstone   (never resurfaces)
//
// The RIG tools MemoryReadTool, MemoryWriteTool, MemoryForgetTool let
// AURA read and write her own memory during inference — called exactly
// like get_time, but for user facts.

use anyhow::Result;
use chrono::Utc;
use rig::completion::ToolDefinition;
use rig::tool::Tool;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::{Arc, Mutex};

// ── Memory entry ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub key:       String,
    pub value:     String,
    pub tier:      MemoryTier,
    pub created:   i64,
    pub expires:   Option<i64>,
    pub forgotten: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum MemoryTier { Permanent, Cache }

// ── The store ─────────────────────────────────────────────────────────────────

#[derive(Clone)]
pub struct MemoryStore {
    db: Arc<Mutex<sled::Db>>,
}

impl MemoryStore {
    pub fn open(model_path: &str) -> Result<Self> {
        let dir = std::path::Path::new(model_path)
            .parent()
            .unwrap_or(std::path::Path::new("."));
        let db_path = dir.join("aura_memory.sleddb");
        let db = sled::open(&db_path)
            .map_err(|e| anyhow::anyhow!("sled open failed: {e}"))?;
        eprintln!("AURA_MEMORY: opened {:?}", db_path);
        Ok(Self { db: Arc::new(Mutex::new(db)) })
    }

    pub fn remember_permanent(&self, key: &str, value: &str) -> Result<()> {
        let entry = MemoryEntry {
            key: key.to_string(), value: value.to_string(),
            tier: MemoryTier::Permanent,
            created: Utc::now().timestamp(), expires: None, forgotten: false,
        };
        self.write_entry("mem:perm:", key, &entry)
    }

    pub fn remember_cache(&self, key: &str, value: &str) -> Result<()> {
        let exp = Utc::now().timestamp() + 30 * 24 * 60 * 60;
        let entry = MemoryEntry {
            key: key.to_string(), value: value.to_string(),
            tier: MemoryTier::Cache,
            created: Utc::now().timestamp(), expires: Some(exp), forgotten: false,
        };
        self.write_entry("mem:cache:", key, &entry)
    }

    pub fn forget(&self, key: &str) -> Result<()> {
        let db = self.db.lock().unwrap();
        let _ = db.remove(format!("mem:perm:{key}").as_bytes());
        let _ = db.remove(format!("mem:cache:{key}").as_bytes());
        db.insert(
            format!("mem:forget:{key}").as_bytes(),
            Utc::now().timestamp().to_le_bytes().as_ref(),
        )?;
        eprintln!("AURA_MEMORY: forgot key={key}");
        Ok(())
    }

    fn write_entry(&self, prefix: &str, key: &str, entry: &MemoryEntry) -> Result<()> {
        let db = self.db.lock().unwrap();
        // Block writes to tombstoned keys
        if db.contains_key(format!("mem:forget:{key}").as_bytes())? {
            eprintln!("AURA_MEMORY: blocked write to forgotten key={key}");
            return Ok(());
        }
        let sled_key = format!("{prefix}{key}");
        db.insert(sled_key.as_bytes(), serde_json::to_vec(entry)?)?;
        eprintln!("AURA_MEMORY: wrote {:?} key={key} value={}", entry.tier, entry.value);
        Ok(())
    }

    pub fn read(&self, key: &str) -> Option<String> {
        let db = self.db.lock().unwrap();
        let now = Utc::now().timestamp();
        if db.contains_key(format!("mem:forget:{key}").as_bytes()).ok()? {
            return None;
        }
        // Permanent first
        if let Some(b) = db.get(format!("mem:perm:{key}").as_bytes()).ok().flatten() {
            if let Ok(e) = serde_json::from_slice::<MemoryEntry>(&b) {
                if !e.forgotten { return Some(e.value); }
            }
        }
        // Cache with expiry check
        if let Some(b) = db.get(format!("mem:cache:{key}").as_bytes()).ok().flatten() {
            if let Ok(e) = serde_json::from_slice::<MemoryEntry>(&b) {
                if !e.forgotten {
                    if e.expires.map(|exp| now < exp).unwrap_or(true) {
                        return Some(e.value);
                    }
                }
            }
        }
        None
    }

    /// Returns all known non-expired, non-forgotten facts.
    pub fn read_all(&self) -> Vec<(String, String)> {
        let db = self.db.lock().unwrap();
        let now = Utc::now().timestamp();
        let mut facts = Vec::new();

        for prefix in &["mem:perm:", "mem:cache:"] {
            for item in db.scan_prefix(prefix.as_bytes()) {
                if let Ok((_, bytes)) = item {
                    if let Ok(e) = serde_json::from_slice::<MemoryEntry>(&bytes) {
                        if e.forgotten { continue; }
                        if db.contains_key(format!("mem:forget:{}", e.key).as_bytes())
                            .unwrap_or(false) { continue; }
                        let expired = e.expires.map(|exp| now >= exp).unwrap_or(false);
                        if !expired {
                            facts.push((e.key.clone(), e.value.clone()));
                        }
                    }
                }
            }
        }
        facts
    }

    /// Formats all facts as a single inject string.
    /// Returns None if no facts stored yet (new user).
    pub fn format_for_injection(&self) -> Option<String> {
        let facts = self.read_all();
        if facts.is_empty() { return None; }
        let pairs: Vec<String> = facts.iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect();
        Some(format!("[AURA remembers: {}]", pairs.join(", ")))
    }
}

// ── Tool: memory_read ─────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct MemoryReadArgs { pub key: String }

#[derive(Serialize)]
pub struct MemoryReadOutput { pub key: String, pub value: Option<String>, pub found: bool }

#[derive(Debug, thiserror::Error)]
#[error("memory read error")]
pub struct MemoryReadError;

pub struct MemoryReadTool { pub store: MemoryStore }

impl Tool for MemoryReadTool {
    const NAME: &'static str = "memory_read";
    type Error = MemoryReadError;
    type Args  = MemoryReadArgs;
    type Output = MemoryReadOutput;

    async fn definition(&self, _: String) -> ToolDefinition {
        ToolDefinition {
            name: "memory_read".to_string(),
            description: "Read a stored fact about the user from AURA's permanent memory. \
                Use when the user references something from a past conversation. \
                Keys: user_name, user_job, user_age, user_mood, user_location, etc."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "key": { "type": "string", "description": "Memory key to look up" }
                },
                "required": ["key"]
            }),
        }
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let value = self.store.read(&args.key);
        let found = value.is_some();
        Ok(MemoryReadOutput { key: args.key, value, found })
    }
}

// ── Tool: memory_write ────────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct MemoryWriteArgs {
    pub key: String,
    pub value: String,
    pub permanent: bool,
}

#[derive(Serialize)]
pub struct MemoryWriteOutput { pub stored: bool, pub key: String, pub tier: String }

#[derive(Debug, thiserror::Error)]
#[error("memory write error")]
pub struct MemoryWriteError;

pub struct MemoryWriteTool { pub store: MemoryStore }

impl Tool for MemoryWriteTool {
    const NAME: &'static str = "memory_write";
    type Error = MemoryWriteError;
    type Args  = MemoryWriteArgs;
    type Output = MemoryWriteOutput;

    async fn definition(&self, _: String) -> ToolDefinition {
        ToolDefinition {
            name: "memory_write".to_string(),
            description: "Store a fact about the user in AURA's memory. \
                permanent=true for facts that should last forever (name, job, relationships). \
                permanent=false for temporary context (today's mood, current task)."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "key":       { "type": "string",  "description": "snake_case key: user_name, user_job, user_mood_today" },
                    "value":     { "type": "string",  "description": "The value to remember" },
                    "permanent": { "type": "boolean", "description": "true=forever, false=30 days" }
                },
                "required": ["key", "value", "permanent"]
            }),
        }
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let result = if args.permanent {
            self.store.remember_permanent(&args.key, &args.value)
        } else {
            self.store.remember_cache(&args.key, &args.value)
        };
        let stored = result.is_ok();
        Ok(MemoryWriteOutput {
            stored,
            key: args.key,
            tier: if args.permanent { "permanent".into() } else { "cache".into() },
        })
    }
}

// ── Tool: memory_forget ───────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct MemoryForgetArgs { pub key: String }

#[derive(Serialize)]
pub struct MemoryForgetOutput { pub forgotten: bool, pub key: String }

#[derive(Debug, thiserror::Error)]
#[error("memory forget error")]
pub struct MemoryForgetError;

pub struct MemoryForgetTool { pub store: MemoryStore }

impl Tool for MemoryForgetTool {
    const NAME: &'static str = "memory_forget";
    type Error = MemoryForgetError;
    type Args  = MemoryForgetArgs;
    type Output = MemoryForgetOutput;

    async fn definition(&self, _: String) -> ToolDefinition {
        ToolDefinition {
            name: "memory_forget".to_string(),
            description: "Permanently delete a stored fact. \
                Use when the user explicitly asks AURA to forget something. Irreversible."
                .to_string(),
            parameters: json!({
                "type": "object",
                "properties": {
                    "key": { "type": "string", "description": "The key to permanently delete" }
                },
                "required": ["key"]
            }),
        }
    }

    async fn call(&self, args: Self::Args) -> Result<Self::Output, Self::Error> {
        let forgotten = self.store.forget(&args.key).is_ok();
        Ok(MemoryForgetOutput { forgotten, key: args.key })
    }
}
