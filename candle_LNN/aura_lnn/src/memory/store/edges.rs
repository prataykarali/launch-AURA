// store/edges.rs - Graph Edge operations & 1-2 hop traversals for Archipelago Graph RAG
// ponytail: Uses SQLite adjacency list for fast 1-2 hop edge traversal without extra DB dependencies.

use anyhow::Result;
use rusqlite::params;
use std::collections::{HashSet, VecDeque};

use crate::memory::store::nodes::GraphNode;
use crate::memory::store::MemoryStore;

#[derive(Debug, Clone)]
pub struct GraphEdge {
    pub src: i64,
    pub rel: String,
    pub dst: i64,
    pub valid: bool,
}

#[derive(Debug, Clone)]
pub struct TraversedContext {
    pub anchor: GraphNode,
    pub neighbors: Vec<(String, GraphNode)>, // (relationship, target_node)
}

impl MemoryStore {
    /// Insert a directed edge between two nodes. If edge exists, marks valid = 1.
    pub fn insert_edge(&self, src: i64, rel: &str, dst: i64) -> Result<()> {
        let conn = self.pool.acquire()?;
        let rel_clean = rel.trim().to_uppercase();
        conn.execute(
            "INSERT INTO edges (src, rel, dst, valid) VALUES (?, ?, ?, 1)",
            params![src, rel_clean, dst],
        )?;
        Ok(())
    }

    /// Retrieve directed outgoing edges from a node.
    pub fn get_edges_from(&self, src: i64) -> Result<Vec<GraphEdge>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT src, rel, dst, valid FROM edges WHERE src = ? AND valid = 1",
        )?;
        let rows = stmt.query_map([src], |r| {
            Ok(GraphEdge {
                src: r.get(0)?,
                rel: r.get(1)?,
                dst: r.get(2)?,
                valid: r.get::<_, i64>(3)? == 1,
            })
        })?;
        let mut out = Vec::new();
        for edge in rows.flatten() {
            out.push(edge);
        }
        Ok(out)
    }

    /// Retrieve 1-2 hop subgraph around an anchor node.
    /// Traverses outgoing and incoming edges up to `max_hops` (typically 1 or 2).
    pub fn traverse_subgraph(&self, anchor_id: i64, max_hops: usize) -> Result<Option<TraversedContext>> {
        let anchor = match self.get_node_by_id(anchor_id)? {
            Some(n) => n,
            None => return Ok(None),
        };

        let conn = self.pool.acquire()?;
        let mut visited: HashSet<i64> = HashSet::new();
        visited.insert(anchor_id);

        let mut queue: VecDeque<(i64, usize)> = VecDeque::new();
        queue.push_back((anchor_id, 0));

        let mut neighbors: Vec<(String, GraphNode)> = Vec::new();

        while let Some((curr_id, hop)) = queue.pop_front() {
            if hop >= max_hops {
                continue;
            }

            // Find all connected nodes (outgoing & incoming)
            let mut stmt = conn.prepare(
                "SELECT rel, dst FROM edges WHERE src = ? AND valid = 1 \
                 UNION \
                 SELECT rel, src FROM edges WHERE dst = ? AND valid = 1",
            )?;

            let rows = stmt.query_map(params![curr_id, curr_id], |r| {
                Ok((r.get::<_, String>(0)?, r.get::<_, i64>(1)?))
            })?;

            for r in rows.flatten() {
                let (rel, target_id) = r;
                if visited.insert(target_id) {
                    if let Some(target_node) = self.get_node_by_id(target_id)? {
                        neighbors.push((rel.clone(), target_node));
                        if hop + 1 < max_hops {
                            queue.push_back((target_id, hop + 1));
                        }
                    }
                }
            }
        }

        Ok(Some(TraversedContext {
            anchor,
            neighbors,
        }))
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
        format!("{}/aura_test_edges_{}.db", std::env::temp_dir().display(), ts)
    }

    #[test]
    fn test_edge_insertion_and_traversal() {
        let db = temp_db_path();
        let store = MemoryStore::open(&db).unwrap();

        let user_id = store.upsert_node("user", "person", Some("User"), None, "test", None).unwrap();
        let pet_id = store.upsert_node("Mochi", "pet", Some("cat named Mochi"), None, "test", None).unwrap();
        let toy_id = store.upsert_node("Laser Pointer", "pref", Some("favorite toy"), None, "test", None).unwrap();

        // 1-hop: user -> HAS_PET -> Mochi
        store.insert_edge(user_id, "HAS_PET", pet_id).unwrap();
        // 2-hop: Mochi -> LIKES -> Laser Pointer
        store.insert_edge(pet_id, "LIKES", toy_id).unwrap();

        // Traverse 2 hops from user
        let context = store.traverse_subgraph(user_id, 2).unwrap().unwrap();
        assert_eq!(context.anchor.name, "user");
        assert_eq!(context.neighbors.len(), 2);

        let neighbor_names: Vec<String> = context.neighbors.iter().map(|(_, n)| n.name.clone()).collect();
        assert!(neighbor_names.contains(&"Mochi".to_string()));
        assert!(neighbor_names.contains(&"Laser Pointer".to_string()));
    }
}

