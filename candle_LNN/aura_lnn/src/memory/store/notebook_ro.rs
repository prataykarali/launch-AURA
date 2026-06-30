// store/notebook_ro.rs - Direct read-only access for notebook/query reads.
//
// Each opens its own short-lived read-only WAL connection to DB_PATH and runs
// the same SQL the worker path runs. These reads must NOT block on the engine
// worker.

use rusqlite::Connection;

use crate::memory::store::facts::split_fact_kv;
use crate::memory::store::pool;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Notebook Turns via a direct read-only connection (never blocks on the
    /// engine worker). Returns the same `{user, aura, ts}` shape the Dart UI
    /// expects. `[]` if the DB isn't open yet.
    pub fn read_notebook_turns_ro(db_path: &str) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        Self::pair_turns_ro(&conn)
    }

    pub fn read_notebook_summaries_ro(db_path: &str) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn
            .prepare("SELECT id, session, summary, timestamp FROM summaries ORDER BY id ASC")
        {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, i64>(3)?,
            ))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok())
            .map(|(id, session, summary, ts)| {
                serde_json::json!({
                    "id": id,
                    "session_id": session,
                    "created_at": ts,
                    "topic_label": "General",
                    "content": summary,
                })
            })
            .collect()
    }

    pub fn read_notebook_facts_ro(db_path: &str) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT id, session, fact, timestamp
             FROM facts
             WHERE fact NOT LIKE 'vision:%'
             ORDER BY id ASC",
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, i64>(3)?,
            ))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok())
            .map(|(_id, _session, fact, ts)| {
                let (key, value) = split_fact_kv(&fact);
                serde_json::json!({
                    "key": key,
                    "value": value,
                    "updated_at": ts,
                })
            })
            .collect()
    }

    pub fn read_notebook_insights_ro(db_path: &str) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT id, kind, content, confidence, evidence_count, source, timestamp
             FROM insights ORDER BY confidence DESC, evidence_count DESC",
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(serde_json::json!({
                "id": row.get::<_, i64>(0)?,
                "kind": row.get::<_, String>(1)?,
                "content": row.get::<_, String>(2)?,
                "confidence": row.get::<_, f64>(3)?,
                "evidence_count": row.get::<_, i64>(4)?,
                "source": row.get::<_, String>(5)?,
                "timestamp": row.get::<_, i64>(6)?,
            }))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    pub fn read_proactive_log_ro(db_path: &str, limit: i64) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT id, trigger_id, label, trigger_type, engaged, timestamp
             FROM proactive_log ORDER BY id DESC LIMIT ?",
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([limit], |row| {
            Ok(serde_json::json!({
                "id": row.get::<_, i64>(0)?,
                "trigger_id": row.get::<_, i64>(1)?,
                "label": row.get::<_, String>(2)?,
                "trigger_type": row.get::<_, String>(3)?,
                "engaged": row.get::<_, i64>(4)? != 0,
                "timestamp": row.get::<_, i64>(5)?,
            }))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    pub fn read_memory_notes_ro(db_path: &str) -> Vec<serde_json::Value> {
        let conn = match pool::open_readonly(db_path) {
            Ok(c) => c,
            Err(_) => return Vec::new(),
        };
        let mut stmt = match conn.prepare(
            "SELECT id, title, content, pinned, timestamp, deleted FROM memory_notes ORDER BY deleted ASC, pinned DESC, id DESC"
        ) {
            Ok(s) => s,
            Err(_) => return Vec::new(),
        };
        let rows = match stmt.query_map([], |row| {
            Ok(serde_json::json!({
                "id": row.get::<_, i64>(0)?,
                "title": row.get::<_, String>(1)?,
                "content": row.get::<_, String>(2)?,
                "pinned": row.get::<_, i64>(3)? != 0,
                "timestamp": row.get::<_, i64>(4)?,
                "deleted": row.get::<_, i64>(5)? != 0,
            }))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    /// Pair consecutive user→assistant turns from a read-only connection.
    /// Mirrors the pooled `get_notebook_turns_paired_json` logic but runs
    /// against an arbitrary `&Connection` (the RO handle).
    fn pair_turns_ro(conn: &Connection) -> Vec<serde_json::Value> {
        let mut stmt =
            match conn.prepare("SELECT speaker, content, timestamp FROM turns ORDER BY id ASC") {
                Ok(s) => s,
                Err(_) => return Vec::new(),
            };
        let rows = match stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)?,
            ))
        }) {
            Ok(r) => r,
            Err(_) => return Vec::new(),
        };
        let rows: Vec<(String, String, i64)> = rows.filter_map(|r| r.ok()).collect();

        let mut out: Vec<serde_json::Value> = Vec::new();
        let mut i = 0;
        while i < rows.len() {
            let (spk, content, ts) = &rows[i];
            if spk == "user" {
                if i + 1 < rows.len() && rows[i + 1].0 == "assistant" {
                    let a = rows[i + 1].1.clone();
                    let aura_ts = rows[i + 1].2;
                    out.push(serde_json::json!({
                        "user": content,
                        "aura": a,
                        "ts": aura_ts,
                    }));
                    i += 2;
                    continue;
                }
                out.push(serde_json::json!({
                    "user": content,
                    "aura": "",
                    "ts": ts,
                }));
                i += 1;
            } else {
                out.push(serde_json::json!({
                    "user": "",
                    "aura": content,
                    "ts": ts,
                }));
                i += 1;
            }
        }
        out
    }
}
