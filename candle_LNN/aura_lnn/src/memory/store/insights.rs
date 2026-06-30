// store/insights.rs - Durable synthesized understandings about the user.
//
// Unlike `vec_memory` (raw conversational recall) and `facts` (identity
// one-liners), insights are synthesized *understandings*: "User prefers
// concise answers", "User is working on AURA", "User dislikes smalltalk".
// They carry a confidence (0..1) and an evidence_count that grows every
// time the same understanding is re-derived, and a last_delta shaped by
// engagement outcomes (+/-). The chat thread injects the top insights so
// the model actually adapts; the notebook surfaces them as a tab.

use anyhow::Result;
use rusqlite::params;

use crate::memory::store::rows::InsightRow;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Upsert an insight. If `content` (case-insensitive) already exists, bump
    /// evidence_count + adjust confidence (clamped to [0,1]); otherwise insert.
    /// Returns the final confidence so the caller can decide whether to (re-)
    /// embed the insight into vec_memory for RAG.
    pub fn upsert_insight(
        &self,
        kind: &str,
        content: &str,
        delta: f32,
        source: &str,
    ) -> Result<f32> {
        let conn = self.pool.acquire()?;
        // Try an update first (exact match on lowercased content).
        let updated = conn.execute(
            "UPDATE insights
             SET evidence_count = evidence_count + 1,
                 confidence = MIN(1.0, MAX(0.0, confidence + ?1)),
                 last_delta = ?1,
                 timestamp = strftime('%s', 'now')
             WHERE lower(content) = lower(?2)",
            params![delta, content],
        )?;
        let final_conf = if updated == 0 {
            // New insight: seed at a neutral 0.5 + the supplied delta.
            let seed = (0.5 + delta).clamp(0.0, 1.0);
            conn.execute(
                "INSERT INTO insights (kind, content, confidence, evidence_count, source, last_delta)
                 VALUES (?, ?, ?, 1, ?, ?)",
                params![kind, content, seed, source, delta],
            )?;
            seed
        } else {
            conn.query_row(
                "SELECT confidence FROM insights WHERE lower(content) = lower(?1)",
                params![content],
                |r| r.get::<_, f32>(0),
            )
            .unwrap_or(0.5)
        };
        Ok(final_conf)
    }

    /// Top-N insights ordered by confidence desc. Used for chat injection and
    /// the notebook Insights tab.
    pub fn get_top_insights(&self, limit: usize) -> Result<Vec<InsightRow>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT kind, content, confidence, evidence_count, source, timestamp
             FROM insights
             WHERE trim(content) != ''
             ORDER BY confidence DESC, evidence_count DESC
             LIMIT ?",
        )?;
        let rows = stmt.query_map([limit as i64], |row| {
            Ok(InsightRow {
                kind: row.get(0)?,
                content: row.get(1)?,
                confidence: row.get(2)?,
                evidence_count: row.get(3)?,
                source: row.get(4)?,
                timestamp: row.get(5)?,
            })
        })?;
        let mut out = Vec::new();
        for i in rows.flatten() {
            out.push(i);
        }
        Ok(out)
    }

    /// Insight rows as strings for chat-context injection. High-confidence
    /// insights are phrased as established knowledge; low-confidence ones are
    /// phrased as soft hints so the model doesn't over-commit.
    pub fn get_insight_strings(&self, limit: usize) -> Result<Vec<String>> {
        let insights = self.get_top_insights(limit)?;
        Ok(insights
            .into_iter()
            .map(|i| {
                let hedge = if i.confidence >= 0.65 {
                    "Understanding"
                } else {
                    "Possible"
                };
                format!("{} ({}): {}", hedge, i.kind, i.content)
            })
            .collect())
    }

    /// Count of insights — runtime diagnostic.
    pub fn insight_count(&self) -> Result<i64> {
        let conn = self.pool.acquire()?;
        let n: i64 = conn.query_row("SELECT COUNT(*) FROM insights", [], |r| r.get(0))?;
        Ok(n)
    }
}
