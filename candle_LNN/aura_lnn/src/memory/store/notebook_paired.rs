// store/notebook_paired.rs - Notebook views paired for the Dart UI.
//
// The legacy `get_all_*_json` emit the per-row shape {session,speaker,
// content,timestamp}; the Dart UI pairs them into {user,aura,ts}. We do
// the pairing server-side here so the notebook populates correctly.
// summarize_history() still reads the raw per-row shape — unchanged.

use anyhow::Result;

use crate::memory::store::facts::split_fact_kv;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Notebook Turns view: pair consecutive user→assistant rows into
    /// `{user, aura, ts}` objects (ts taken from the assistant row). This is
    /// the shape `notebook_page.dart` `_Turn.fromJson` expects.
    pub fn get_notebook_turns_paired_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt =
            conn.prepare("SELECT speaker, content, timestamp FROM turns ORDER BY id ASC")?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let mut out: Vec<serde_json::Value> = Vec::new();
        let mut i = 0;
        while i < rows.len() {
            let (spk, content, ts) = &rows[i];
            if spk == "user" {
                // Look for the following assistant turn.
                let aura = if i + 1 < rows.len() && rows[i + 1].0 == "assistant" {
                    let a = rows[i + 1].1.clone();
                    let aura_ts = rows[i + 1].2;
                    i += 2;
                    // emit with assistant timestamp; fall through
                    out.push(serde_json::json!({
                        "user": content,
                        "aura": a,
                        "ts": aura_ts,
                    }));
                    continue;
                } else {
                    String::new()
                };
                // No matching assistant turn — emit a lone user entry.
                out.push(serde_json::json!({
                    "user": content,
                    "aura": aura,
                    "ts": ts,
                }));
                i += 1;
            } else {
                // An assistant turn without a preceding user (e.g. proactive).
                // Skip pairing but still surface it as an aura-only entry so the
                // notebook doesn't lose proactive chatter.
                out.push(serde_json::json!({
                    "user": "",
                    "aura": content,
                    "ts": ts,
                }));
                i += 1;
            }
        }
        Ok(serde_json::to_string_pretty(&out)?)
    }

    /// Notebook Summaries view: reshape `{session,summary,timestamp}` rows into
    /// `{id, session_id, created_at, topic_label, content}` for the Dart UI.
    pub fn get_notebook_summaries_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt =
            conn.prepare("SELECT id, session, summary, timestamp FROM summaries ORDER BY id ASC")?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let out: Vec<serde_json::Value> = rows
            .into_iter()
            .map(|(id, session, summary, ts)| {
                serde_json::json!({
                    "id": id,
                    "session_id": session,
                    "created_at": ts,
                    "topic_label": "General",
                    "content": summary,
                })
            })
            .collect();
        Ok(serde_json::to_string_pretty(&out)?)
    }

    /// Notebook Facts view: reshape `{session,fact,timestamp}` rows into
    /// `{key, value, updated_at}`. The stored fact is a single blob (e.g.
    /// "User's name is Pratay"); we split on the first ':' if present to derive
    /// a (key,value) pair, otherwise fall back to key="fact".
    pub fn get_notebook_facts_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT id, session, fact, timestamp
             FROM facts
             WHERE fact NOT LIKE 'vision:%'
             ORDER BY id ASC",
        )?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let out: Vec<serde_json::Value> = rows
            .into_iter()
            .map(|(_id, _session, fact, ts)| {
                let (key, value) = split_fact_kv(&fact);
                serde_json::json!({
                    "key": key,
                    "value": value,
                    "updated_at": ts,
                })
            })
            .collect();
        Ok(serde_json::to_string_pretty(&out)?)
    }
}
