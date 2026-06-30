// store/json_export.rs - Raw JSON dumps for turns, summaries, and facts.

use anyhow::Result;

use crate::memory::store::MemoryStore;

impl MemoryStore {
    pub fn get_all_turns_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT session, speaker, content, timestamp 
             FROM turns 
             ORDER BY timestamp ASC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let json_rows: Vec<serde_json::Value> = rows
            .iter()
            .map(|(session, speaker, content, timestamp)| {
                serde_json::json!({
                    "session": session,
                    "speaker": speaker,
                    "content": content,
                    "timestamp": timestamp
                })
            })
            .collect();

        Ok(serde_json::to_string_pretty(&json_rows)?)
    }

    pub fn get_all_summaries_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT session, summary, timestamp 
             FROM summaries 
             ORDER BY timestamp ASC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let json_rows: Vec<serde_json::Value> = rows
            .iter()
            .map(|(session, summary, timestamp)| {
                serde_json::json!({
                    "session": session,
                    "summary": summary,
                    "timestamp": timestamp
                })
            })
            .collect();

        Ok(serde_json::to_string_pretty(&json_rows)?)
    }

    pub fn get_all_facts_json(&self) -> Result<String> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT session, fact, timestamp
             FROM facts
             WHERE fact NOT LIKE 'vision:%'
             ORDER BY timestamp ASC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let json_rows: Vec<serde_json::Value> = rows
            .iter()
            .map(|(session, fact, timestamp)| {
                serde_json::json!({
                    "session": session,
                    "fact": fact,
                    "timestamp": timestamp
                })
            })
            .collect();

        Ok(serde_json::to_string_pretty(&json_rows)?)
    }
}
