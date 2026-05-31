use rusqlite::{Connection, Result as SqlResult};
use rusqlite::ffi::sqlite3_auto_extension;
use sqlite_vec::sqlite3_vec_init;
use std::time::{SystemTime, UNIX_EPOCH};
use std::collections::HashMap;
use anyhow::Result;

// ── FACTS CACHE ──────────────────────────────────────────────────────────────

pub struct FactsCache {
    inner: HashMap<String, String>,
}

impl FactsCache {
    pub fn load_from_db(conn: &Connection) -> rusqlite::Result<Self> {
        let mut inner = HashMap::new();
        let mut stmt = conn.prepare("SELECT key, value FROM facts")?;
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;
        for row in rows {
            let (k, v) = row?;
            inner.insert(k, v);
        }
        Ok(Self { inner })
    }

    pub fn get(&self, key: &str) -> Option<&str> {
        self.inner.get(key).map(|s| s.as_str())
    }

    pub fn set(&mut self, key: &str, value: &str, conn: &Connection) -> rusqlite::Result<()> {
        self.inner.insert(key.to_string(), value.to_string());
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;
        conn.execute(
            "INSERT OR REPLACE INTO facts (key, value, updated_at) VALUES (?1, ?2, ?3)",
            rusqlite::params![key, value, ts],
        )?;
        Ok(())
    }
}
pub struct MemoryStore {
    pub conn: Connection,
    pub facts_cache: FactsCache,
}

impl MemoryStore {pub fn open(db_path: &str) -> SqlResult<Self> {
    unsafe {
        sqlite3_auto_extension(Some(
            std::mem::transmute(sqlite3_vec_init as *const ())
        ));
    }
    let conn = Connection::open(db_path)?;
    conn.execute_batch("PRAGMA journal_mode=WAL;")?;
    let mut store = Self {
        conn,
        facts_cache: FactsCache { inner: HashMap::new() },
    };
    store.create_tables()?;
    store.facts_cache = FactsCache::load_from_db(&store.conn)?;
    Ok(store)
}

    fn create_tables(&self) -> SqlResult<()> {
        self.conn.execute_batch("
            CREATE TABLE IF NOT EXISTS episodes (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id  TEXT    NOT NULL,
                timestamp   INTEGER NOT NULL,
                role        TEXT    NOT NULL,
                content     TEXT    NOT NULL,
                summary     TEXT
            );

            CREATE TABLE IF NOT EXISTS facts (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                key         TEXT    NOT NULL UNIQUE,
                value       TEXT    NOT NULL,
                updated_at  INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS diary (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id  TEXT    NOT NULL,
                timestamp   INTEGER NOT NULL,
                content     TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS proactive_triggers (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                trigger_type TEXT    NOT NULL,
                scheduled_at INTEGER NOT NULL,
                label        TEXT    NOT NULL,
                fired        INTEGER NOT NULL DEFAULT 0
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS episode_embeddings USING vec0(
                episode_id  integer primary key,
                embedding   float[384] distance_metric=cosine
            );
    ")?;
    Ok(())
}

// ── READ ─────────────────────────────────────────────────────────────────

    pub fn load_relevant_episodes(
        &self,
        query: &str,
        n: usize,
        embedder: &mut super::embed::Embedder,
    ) -> Result<String> {
        let query_vec = match embedder.embed(query) {
            Ok(v)  => v,
            Err(_) => return Ok(self.load_recent_episodes(n).unwrap_or_default()),
        };
        let query_bytes = super::embed::Embedder::to_bytes(&query_vec);

        let mut stmt = self.conn.prepare(
            "SELECT e.role, e.content
             FROM episode_embeddings ee
             JOIN episodes e ON e.id = ee.episode_id
             WHERE embedding MATCH ?1
               AND k = ?2
             ORDER BY ee.distance ASC"
        )?;

        let rows: Vec<(String, String)> = stmt
            .query_map(rusqlite::params![query_bytes, n as i64], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })?
            .filter_map(|r| r.ok())
            .collect();

        if rows.is_empty() {
            return Ok(self.load_recent_episodes(n).unwrap_or_default());
        }

        let lines: Vec<String> = rows
            .iter()
            .map(|(role, content)| format!("{}: {}", role, content))
            .collect();

        Ok(format!(
            "=== AURA'S MEMORY — READ THIS FIRST ===\n{}\n=== END MEMORY ===",
            lines.join("\n")
        ))
    }

    pub fn load_recent_episodes(&self, n: usize) -> rusqlite::Result<String> {
        let mut stmt = self.conn.prepare(
            "SELECT role, content FROM episodes
             ORDER BY timestamp DESC
             LIMIT ?1"
        )?;
        let rows = stmt.query_map(rusqlite::params![n as i64], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?;

        let mut episodes: Vec<(String, String)> = rows
            .filter_map(|r| r.ok())
            .collect();

        episodes.reverse(); // oldest first

        if episodes.is_empty() {
            return Ok(String::new());
        }

        let lines: Vec<String> = episodes
            .iter()
            .map(|(role, content)| format!("{}: {}", role, content))
            .collect();

        Ok(format!(
            "=== AURA'S MEMORY — READ THIS FIRST ===\n{}\n=== END MEMORY ===",
            lines.join("\n")
        ))
    }
pub fn load_facts_as_context(&self) -> rusqlite::Result<String> {
    let facts: Vec<String> = self.facts_cache.inner.iter()
        .map(|(k, v)| match k.as_str() {
            "user_name"     => format!("The user's name is {}. Use it naturally.", v),
            "user_age"      => format!("The user is {} years old.", v),
            "user_likes"    => format!("The user likes/loves: {}", v),
            "user_dislikes" => format!("The user dislikes: {}", v),
            "user_feeling"  => format!("The user recently felt: {}", v),
            "user_location" => format!("The user is from/lives in: {}", v),
            _               => format!("{}: {}", k, v),
        })
        .collect();

    if facts.is_empty() {
        return Ok(String::new());
    }

    Ok(format!(
        "=== FACTS ABOUT THE USER — TRUST THESE COMPLETELY ===\n{}\n===",
        facts.join("\n")
    ))
}

    pub fn get_all_turns_json(&self) -> Result<String> {
        let mut stmt = self.conn.prepare(
            "SELECT role, content, timestamp FROM episodes ORDER BY id ASC"
        )?;

        let rows: Vec<(String, String, i64)> = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)?,
            ))
        })?
        .filter_map(|r| r.ok())
        .collect();

        let mut turns = vec![];
        let mut i = 0;
        while i + 1 < rows.len() {
            let (role_a, content_a, ts) = &rows[i];
            let (role_b, content_b, _)  = &rows[i + 1];
            if role_a == "user" && role_b == "aura" {
                turns.push(serde_json::json!({
                    "user": content_a,
                    "aura": content_b,
                    "ts":   ts / 1000
                }));
                i += 2;
            } else {
                i += 1;
            }
        }

        Ok(serde_json::to_string(&turns)?)
    }

    // ── WRITE ────────────────────────────────────────────────────────────────

    pub fn insert_episode(
        &self,
        session_id: &str,
        role: &str,
        content: &str,
        embedder: &mut super::embed::Embedder,
    ) -> rusqlite::Result<()> {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as i64;

        let tx = self.conn.unchecked_transaction()?;
        tx.execute(
            "INSERT INTO episodes (session_id, timestamp, role, content)
             VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![session_id, timestamp, role, content],
        )?;
        let episode_id = tx.last_insert_rowid();

        if let Ok(embedding) = embedder.embed(content) {
            let bytes = super::embed::Embedder::to_bytes(&embedding);
            tx.execute(
                "INSERT INTO episode_embeddings (episode_id, embedding)
                 VALUES (?1, ?2)",
                rusqlite::params![episode_id, bytes],
            )?;
        }
        tx.commit()?;
        Ok(())
    }

    pub fn upsert_fact(&mut self, key: &str, value: &str) -> rusqlite::Result<()> {
    self.facts_cache.set(key, value, &self.conn)
}
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn facts_cache_roundtrip() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("
            CREATE TABLE facts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT NOT NULL UNIQUE,
                value TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
        ").unwrap();

        let mut cache = FactsCache::load_from_db(&conn).unwrap();
        assert_eq!(cache.get("user_name"), None);

        cache.set("user_name", "Aryan", &conn).unwrap();
        assert_eq!(cache.get("user_name"), Some("Aryan"));

        // Reload from DB — proves write-through works
        let cache2 = FactsCache::load_from_db(&conn).unwrap();
        assert_eq!(cache2.get("user_name"), Some("Aryan"));
    }
}

#[test]
fn facts_cache_vs_sqlite_benchmark() {
    let conn = Connection::open_in_memory().unwrap();
    conn.execute_batch("
        CREATE TABLE facts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT NOT NULL UNIQUE,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        );
    ").unwrap();

    // Seed 20 facts
    let keys = ["user_name","user_age","user_likes","user_dislikes","user_feeling",
                 "user_location","fav_color","fav_food","fav_music","fav_movie",
                 "pet_name","school","hobby","dream","fear",
                 "birthday","city","language","timezone","mood"];
    for (i, key) in keys.iter().enumerate() {
        conn.execute(
            "INSERT OR REPLACE INTO facts (key, value, updated_at) VALUES (?1, ?2, ?3)",
            rusqlite::params![key, format!("value_{}", i), 0i64],
        ).unwrap();
    }

    let iterations = 1000usize;

    // SQLite path
    let t0 = std::time::Instant::now();
    for _ in 0..iterations {
        let mut stmt = conn.prepare("SELECT value FROM facts WHERE key = ?1").unwrap();
        let _: String = stmt.query_row(rusqlite::params!["user_name"], |r| r.get(0)).unwrap();
    }
    let sqlite_ms = t0.elapsed().as_micros();

    // HashMap path
    let cache = FactsCache::load_from_db(&conn).unwrap();
    let t1 = std::time::Instant::now();
    for _ in 0..iterations {
        let _ = cache.get("user_name");
    }
    let hashmap_us = t1.elapsed().as_micros();

    eprintln!(
        "\n[BENCH] {} lookups — SQLite: {}µs | HashMap: {}µs | speedup: {:.0}x",
        iterations,
        sqlite_ms,
        hashmap_us,
        sqlite_ms as f64 / hashmap_us.max(1) as f64
    );

    assert!(hashmap_us < sqlite_ms, "HashMap should be faster than SQLite");
}