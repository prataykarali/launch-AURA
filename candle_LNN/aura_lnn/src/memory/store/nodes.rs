// store/nodes.rs - Graph Node CRUD & Vector Search operations for Archipelago Graph RAG
// ponytail: Uses SQLite for nodes table and cosine scan. Fits small personal memory without heavy graph DB.

use anyhow::Result;
use rusqlite::params;
use serde::{Deserialize, Serialize};

use crate::memory::store::utils::safe_context_memory;
use crate::memory::store::MemoryStore;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
    pub id: i64,
    pub name: String,
    pub kind: String,
    pub summary: Option<String>,
    pub attrs: Option<String>,
    pub source: String,
    pub updated_at: i64,
}

impl MemoryStore {
    /// Upsert a graph node by (name, kind). If it exists, updates summary, attrs, and updated_at.
    /// Returns the node ID.
    pub fn upsert_node(
        &self,
        name: &str,
        kind: &str,
        summary: Option<&str>,
        attrs: Option<&str>,
        source: &str,
        embedding: Option<&[f32]>,
    ) -> Result<i64> {
        let conn = self.pool.acquire()?;
        let trimmed_name = name.trim();
        let trimmed_kind = kind.trim().to_lowercase();
        if trimmed_name.is_empty() || trimmed_kind.is_empty() {
            anyhow::bail!("Node name and kind cannot be empty");
        }

        let emb_blob: Option<Vec<u8>> = embedding.map(|vec| {
            let mut bytes = Vec::with_capacity(vec.len() * 4);
            for f in vec {
                bytes.extend_from_slice(&f.to_le_bytes());
            }
            bytes
        });

        // Check if node already exists
        let existing_id: Option<i64> = conn
            .query_row(
                "SELECT id FROM nodes WHERE LOWER(name) = LOWER(?) AND kind = ?",
                params![trimmed_name, trimmed_kind],
                |r| r.get(0),
            )
            .ok();

        if let Some(id) = existing_id {
            if let Some(ref blob) = emb_blob {
                conn.execute(
                    "UPDATE nodes SET summary = COALESCE(?, summary), attrs = COALESCE(?, attrs), \
                     source = ?, updated_at = (strftime('%s', 'now')), embedding = ? WHERE id = ?",
                    params![summary, attrs, source, blob, id],
                )?;
            } else {
                conn.execute(
                    "UPDATE nodes SET summary = COALESCE(?, summary), attrs = COALESCE(?, attrs), \
                     source = ?, updated_at = (strftime('%s', 'now')) WHERE id = ?",
                    params![summary, attrs, source, id],
                )?;
            }
            Ok(id)
        } else {
            conn.execute(
                "INSERT INTO nodes (name, kind, summary, attrs, source, updated_at, embedding) \
                 VALUES (?, ?, ?, ?, ?, (strftime('%s', 'now')), ?)",
                params![trimmed_name, trimmed_kind, summary, attrs, source, emb_blob],
            )?;
            Ok(conn.last_insert_rowid())
        }
    }

    pub fn get_node_by_id(&self, id: i64) -> Result<Option<GraphNode>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, kind, summary, attrs, source, updated_at FROM nodes WHERE id = ?",
        )?;
        let mut rows = stmt.query_map([id], |r| {
            Ok(GraphNode {
                id: r.get(0)?,
                name: r.get(1)?,
                kind: r.get(2)?,
                summary: r.get(3)?,
                attrs: r.get(4)?,
                source: r.get(5)?,
                updated_at: r.get(6)?,
            })
        })?;

        if let Some(row) = rows.next() {
            Ok(Some(row?))
        } else {
            Ok(None)
        }
    }

    pub fn get_node_by_name_kind(&self, name: &str, kind: &str) -> Result<Option<GraphNode>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, kind, summary, attrs, source, updated_at FROM nodes \
             WHERE LOWER(name) = LOWER(?) AND kind = ? LIMIT 1",
        )?;
        let mut rows = stmt.query_map(params![name.trim(), kind.trim().to_lowercase()], |r| {
            Ok(GraphNode {
                id: r.get(0)?,
                name: r.get(1)?,
                kind: r.get(2)?,
                summary: r.get(3)?,
                attrs: r.get(4)?,
                source: r.get(5)?,
                updated_at: r.get(6)?,
            })
        })?;

        if let Some(row) = rows.next() {
            Ok(Some(row?))
        } else {
            Ok(None)
        }
    }

    pub fn get_nodes_by_kind(&self, kind: &str) -> Result<Vec<GraphNode>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT id, name, kind, summary, attrs, source, updated_at FROM nodes \
             WHERE kind = ? ORDER BY updated_at DESC",
        )?;
        let rows = stmt.query_map([kind.trim().to_lowercase()], |r| {
            Ok(GraphNode {
                id: r.get(0)?,
                name: r.get(1)?,
                kind: r.get(2)?,
                summary: r.get(3)?,
                attrs: r.get(4)?,
                source: r.get(5)?,
                updated_at: r.get(6)?,
            })
        })?;
        let mut out = Vec::new();
        for node in rows.flatten() {
            out.push(node);
        }
        Ok(out)
    }

    /// Search nodes with cosine similarity against node embeddings.
    /// Filters by minimum cosine similarity firewall (default 0.62 for strict memory injection).
    pub fn search_nodes_cosine(
        &self,
        query_embedding: &[f32],
        min_cosine: f32,
        limit: usize,
    ) -> Result<Vec<(GraphNode, f32)>> {
        let conn = self.pool.acquire()?;
        let dim = query_embedding.len();

        let mut stmt = conn.prepare(
            "SELECT id, name, kind, summary, attrs, source, updated_at, embedding \
             FROM nodes WHERE embedding IS NOT NULL",
        )?;

        let rows = stmt.query_map([], |row| {
            let node = GraphNode {
                id: row.get(0)?,
                name: row.get(1)?,
                kind: row.get(2)?,
                summary: row.get(3)?,
                attrs: row.get(4)?,
                source: row.get(5)?,
                updated_at: row.get(6)?,
            };
            let blob: Vec<u8> = row.get(7)?;
            Ok((node, blob))
        })?;

        let mut scored: Vec<(GraphNode, f32)> = Vec::new();
        for r in rows {
            let (node, blob) = r?;
            if blob.len() / 4 != dim {
                continue;
            }
            let emb: Vec<f32> = blob
                .chunks_exact(4)
                .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                .collect();

            let mut cosine = 0f32;
            for (a, b) in query_embedding.iter().zip(emb.iter()) {
                cosine += a * b;
            }

            if cosine >= min_cosine {
                if let Some(ref sum) = node.summary {
                    if !safe_context_memory(sum) {
                        continue;
                    }
                }
                scored.push((node, cosine));
            }
        }

        // Sort descending by cosine score
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        if scored.len() > limit {
            scored.truncate(limit);
        }
        Ok(scored)
    }

    /// Reset and wipe all memory data completely.
    pub fn wipe_all_memory(&self, reason: Option<&str>) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute_batch(
            "
            DELETE FROM turns;
            DELETE FROM summaries;
            DELETE FROM facts;
            DELETE FROM vec_memory;
            DELETE FROM memory_notes;
            DELETE FROM insights;
            DELETE FROM proactive_log;
            DELETE FROM nodes;
            DELETE FROM edges;
            INSERT INTO memory_wipe_log (reason) VALUES (?);
            ",
        )?;
        let _ = conn.execute("INSERT INTO memory_wipe_log (reason) VALUES (?)", params![reason]);
        eprintln!("[MEMORY] All memory layers wiped cleanly (reason: {:?})", reason);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_db_path() -> String {
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        format!("{}/aura_test_nodes_{}.db", std::env::temp_dir().display(), ts)
    }

    #[test]
    fn test_node_upsert_and_retrieval() {
        let db = temp_db_path();
        let store = MemoryStore::open(&db).unwrap();

        let id = store
            .upsert_node("Mochi", "pet", Some("User's cat Mochi"), None, "test", None)
            .unwrap();
        assert!(id > 0);

        let node = store.get_node_by_name_kind("Mochi", "pet").unwrap().unwrap();
        assert_eq!(node.name, "Mochi");
        assert_eq!(node.kind, "pet");
        assert_eq!(node.summary.as_deref(), Some("User's cat Mochi"));
    }

    #[test]
    fn test_cosine_firewall() {
        let db = temp_db_path();
        let store = MemoryStore::open(&db).unwrap();

        // 2-dim normalized embeddings for easy math
        let emb1 = vec![1.0f32, 0.0f32];
        let emb2 = vec![0.5f32, 0.866f32]; // dot with [1, 0] = 0.5 (below 0.62)
        let emb3 = vec![0.8f32, 0.6f32];   // dot with [1, 0] = 0.8 (above 0.62)

        store.upsert_node("Node1", "pref", Some("Match 1.0"), None, "test", Some(&emb1)).unwrap();
        store.upsert_node("Node2", "pref", Some("Low match 0.5"), None, "test", Some(&emb2)).unwrap();
        store.upsert_node("Node3", "pref", Some("High match 0.8"), None, "test", Some(&emb3)).unwrap();

        let query = vec![1.0f32, 0.0f32];
        let results = store.search_nodes_cosine(&query, 0.62, 10).unwrap();

        // Only Node1 (1.0) and Node3 (0.8) should pass the 0.62 firewall
        assert_eq!(results.len(), 2);
        assert_eq!(results[0].0.name, "Node1");
        assert_eq!(results[1].0.name, "Node3");
    }

    #[test]
    fn test_memory_wipe() {
        let db = temp_db_path();
        let store = MemoryStore::open(&db).unwrap();

        store.upsert_node("Mochi", "pet", Some("cat"), None, "test", None).unwrap();
        assert_eq!(store.get_nodes_by_kind("pet").unwrap().len(), 1);

        store.wipe_all_memory(Some("User requested wipe")).unwrap();
        assert_eq!(store.get_nodes_by_kind("pet").unwrap().len(), 0);
    }
}

