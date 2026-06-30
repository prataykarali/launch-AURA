// store/vec_memory.rs - Vector-memory writes and migration helpers.

use anyhow::Result;
use rusqlite::params;

use crate::memory::store::utils::{cap_chars, safe_context_memory};
use crate::memory::store::MemoryStore;

impl MemoryStore {
    pub fn insert_vec_memory(&self, content: &str, embedding: &[f32]) -> Result<()> {
        if !safe_context_memory(content) {
            return Ok(());
        }
        let content = cap_chars(content.trim(), crate::memory::store::MAX_VEC_MEMORY_CHARS);
        if content.is_empty() {
            return Ok(());
        }
        let conn = self.pool.acquire()?;
        let bytes: Vec<u8> = embedding.iter().flat_map(|f| f.to_le_bytes()).collect();
        conn.execute(
            "INSERT INTO vec_memory (content, embedding) VALUES (?, ?)",
            params![content, bytes],
        )?;
        Ok(())
    }

    /// Return true if `vec_memory` has rows but NONE match the expected embed
    /// dimension — i.e. old chat-model (512-d) rows that need re-embedding with
    /// the new dedicated embedder (768-d). Drives the one-time migration.
    pub fn needs_reembed(&self, expected_dim: usize) -> Result<bool> {
        let conn = self.pool.acquire()?;
        let total: i64 = conn.query_row(
            "SELECT COUNT(*) FROM vec_memory WHERE embedding IS NOT NULL",
            [],
            |r| r.get(0),
        )?;
        if total == 0 {
            return Ok(false); // nothing to migrate
        }
        // Count rows whose embedding length matches expected_dim.
        let mut rows =
            conn.prepare("SELECT embedding FROM vec_memory WHERE embedding IS NOT NULL")?;
        let matching: i64 = rows
            .query_map([], |row| row.get::<_, Vec<u8>>(0))?
            .filter_map(|r| r.ok())
            .filter(|blob| blob.len() / 4 == expected_dim)
            .count() as i64;
        Ok(matching == 0)
    }

    /// Fetch the text content of ALL vec_memory rows (for the re-embed
    /// migration — we re-embed the stored text with the new embedder).
    pub fn get_all_vec_memory_text(&self) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare("SELECT content FROM vec_memory ORDER BY id ASC")?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;
        let mut out = Vec::new();
        for s in rows.flatten() {
            if !s.trim().is_empty() && safe_context_memory(&s) {
                out.push(s);
            }
        }
        Ok(out)
    }

    /// Delete vec_memory rows whose embedding dimension does NOT match the
    /// expected dim — clears out old chat-model rows after re-embedding.
    pub fn delete_stale_vec_memory(&self, expected_dim: usize) -> Result<()> {
        let conn = self.pool.acquire()?;
        // SQLite has no per-row blob-length filter in a DELETE, so we collect
        // the stale ids first then delete them in one statement.
        let stale_ids: Vec<i64> = {
            let mut stmt =
                conn.prepare("SELECT id, embedding FROM vec_memory WHERE embedding IS NOT NULL")?;
            let rows = stmt.query_map([], |row| {
                let id: i64 = row.get(0)?;
                let blob: Vec<u8> = row.get(1)?;
                Ok((id, blob))
            })?;
            // Fully consume the iterator (which borrows `stmt`) into a Vec here,
            // before `stmt` is dropped at the end of this block.
            rows.filter_map(|r| r.ok())
                .filter(|(_id, blob)| blob.len() / 4 != expected_dim)
                .map(|(id, _)| id)
                .collect()
        };
        if stale_ids.is_empty() {
            return Ok(());
        }
        // Build a parameterized IN-clause. Bounded by row count (small).
        let placeholders: Vec<String> = stale_ids.iter().map(|_| "?".to_string()).collect();
        let sql = format!(
            "DELETE FROM vec_memory WHERE id IN ({})",
            placeholders.join(",")
        );
        let params: Vec<&dyn rusqlite::ToSql> = stale_ids
            .iter()
            .map(|id| id as &dyn rusqlite::ToSql)
            .collect();
        conn.execute(&sql, params.as_slice())?;
        Ok(())
    }

    /// Return turn texts that have no corresponding entry in `vec_memory`.
    /// Used after a mirror re-seed to embed the re-seeded turns so RAG works.
    pub fn get_turn_texts_needing_embedding(&self) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT t.content FROM turns t
             WHERE t.content IS NOT NULL AND t.content != ''
               AND NOT EXISTS (
                   SELECT 1 FROM vec_memory v WHERE v.content = t.content
               )
             ORDER BY t.id ASC",
        )?;
        let rows = stmt.query_map([], |row| row.get::<_, String>(0))?;
        let mut out = Vec::new();
        for s in rows.flatten() {
            if safe_context_memory(&s) {
                out.push(s);
            }
        }
        Ok(out)
    }

    /// Semantic-only retrieval (RAG). Kept for older call sites; internally this
    /// uses the exact hybrid scorer with no lexical query text.
    pub fn search_relevant(&self, query_embedding: &[f32], limit: usize) -> Result<Vec<String>> {
        self.search_relevant_hybrid("", query_embedding, limit)
    }
}
