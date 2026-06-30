// store/search.rs - Semantic + hybrid retrieval over vec_memory.

use anyhow::Result;
use std::collections::{HashMap, HashSet};

use crate::memory::store::retrieval_utils::{normalize_for_dedup, retrieval_tokens};
use crate::memory::store::utils::safe_context_memory;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Exact hybrid retrieval for the small personal DB.
    ///
    /// Two-pass BM25 + cosine:
    ///   Pass 1 — load ALL valid docs; compute corpus document-frequencies for IDF.
    ///   Pass 2 — score each doc: cosine (dominant) + BM25(IDF×TF-norm) + recency hint.
    ///
    /// Why no scan_limit: for AURA's ~100-row personal DB the full table scan is
    /// O(100) — negligible — and guarantees we never miss a fact due to timestamp
    /// ordering. HNSW would only introduce approximation error at this scale.
    pub fn search_relevant_hybrid(
        &self,
        query: &str,
        query_embedding: &[f32],
        limit: usize,
    ) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let dim = query_embedding.len();

        // ── Pass 1: load ALL valid docs ────────────────────────────────────
        let mut stmt = conn.prepare(
            "SELECT content, embedding FROM vec_memory \
             WHERE embedding IS NOT NULL \
             ORDER BY timestamp DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, Vec<u8>>(1)?))
        })?;

        let q_tokens = retrieval_tokens(query);

        // (content, cosine_score, doc_tokens)
        let mut entries: Vec<(String, f32, Vec<String>)> = Vec::new();
        for row in rows {
            let (content, blob) = row?;
            if blob.len() / 4 != dim {
                continue; // stale row with a different embedding dim
            }
            let emb: Vec<f32> = blob
                .chunks_exact(4)
                .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                .collect();
            let mut cosine = 0f32;
            for (a, b) in query_embedding.iter().zip(emb.iter()) {
                cosine += a * b;
            }
            if cosine < 0.50 || !safe_context_memory(&content) {
                continue;
            }
            let tokens = retrieval_tokens(&content);
            entries.push((content, cosine, tokens));
        }

        if entries.is_empty() {
            return Ok(Vec::new());
        }

        // ── BM25 IDF computation over the scanned corpus ───────────────────
        const K1: f32 = 1.5;
        const B: f32 = 0.75;

        let n_docs = entries.len();
        let avg_doc_len: f32 = {
            let total: usize = entries.iter().map(|(_, _, toks)| toks.len()).sum();
            (total as f32 / n_docs as f32).max(1.0)
        };

        // corpus doc-frequencies: how many docs contain each query token?
        let mut doc_freqs: HashMap<String, usize> = HashMap::new();
        if !q_tokens.is_empty() {
            for (_, _, toks) in &entries {
                let mut seen_in_doc: HashSet<&str> = HashSet::new();
                for tok in toks {
                    if seen_in_doc.insert(tok.as_str()) {
                        *doc_freqs.entry(tok.clone()).or_default() += 1;
                    }
                }
            }
        }

        // ── Pass 2: score ──────────────────────────────────────────────────
        let mut scored: Vec<(f32, i64, String)> = Vec::new();
        for (content, cosine, doc_toks) in entries {
            let bm25_scaled = if q_tokens.is_empty() || doc_toks.is_empty() {
                0.0f32
            } else {
                let doc_len = doc_toks.len() as f32;
                // per-doc term frequencies
                let mut tf_map: HashMap<&str, usize> = HashMap::new();
                for tok in &doc_toks {
                    *tf_map.entry(tok.as_str()).or_default() += 1;
                }
                let mut bm25 = 0.0f32;
                for tok in &q_tokens {
                    let tf = *tf_map.get(tok.as_str()).unwrap_or(&0) as f32;
                    if tf == 0.0 {
                        continue;
                    }
                    let df = *doc_freqs.get(tok).unwrap_or(&0) as f32;
                    // Robertson IDF with smoothing (floor at 0)
                    let idf = ((n_docs as f32 - df + 0.5) / (df + 0.5) + 1.0)
                        .ln()
                        .max(0.0);
                    let tf_norm =
                        tf * (K1 + 1.0) / (tf + K1 * (1.0 - B + B * doc_len / avg_doc_len));
                    bm25 += idf * tf_norm;
                }
                // Scale to be comparable with cosine (~0..1). BM25 peaks ~5-10
                // for short personal-DB snippets; cap contribution at 0.35 so
                // cosine stays dominant for semantic matches.
                (bm25 * 0.08).min(0.35)
            };

            let recency_hint = if content.starts_with("Fact")
                || content.starts_with("User")
                || content.contains("User's")
            {
                0.08
            } else {
                0.0
            };

            let final_score = cosine + bm25_scaled + recency_hint;
            scored.push((final_score, content.len() as i64, content));
        }

        scored.sort_by(|a, b| {
            b.0.partial_cmp(&a.0)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.1.cmp(&b.1))
        });

        let mut seen = HashSet::new();
        let mut out = Vec::with_capacity(limit);
        for (_, _, content) in scored {
            let key = normalize_for_dedup(&content);
            if key.is_empty() || !safe_context_memory(&content) || !seen.insert(key) {
                continue;
            }
            out.push(content);
            if out.len() >= limit {
                break;
            }
        }
        Ok(out)
    }

    /// Hybrid retrieval: real cosine similarity over `vec_memory` (semantic),
    /// blended with the priority-weighted recency buckets (facts/summaries/turns).
    /// Previously `search_memory` ignored the query vector entirely (`_query_bytes`
    /// was unused) — so retrieval was pure recency and felt irrelevant. Now the
    /// embedding actually drives relevance.
    pub fn search_memory(&self, query_embedding: &[f32], limit: usize) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let max_items = limit.max(3) as i64;
        let mut results: Vec<(f64, String)> = Vec::new();

        // 1. Semantic: cosine similarity over vec_memory (vectors are L2-normalized
        //    on insert, so dot product == cosine similarity).
        {
            let dim = query_embedding.len();
            let mut stmt = conn.prepare(
                "SELECT content, embedding FROM vec_memory WHERE embedding IS NOT NULL ORDER BY timestamp DESC"
            )?;
            let rows = stmt.query_map([], |row| {
                let content: String = row.get(0)?;
                let blob: Vec<u8> = row.get(1)?;
                Ok((content, blob))
            })?;
            for row in rows {
                let (content, blob) = row?;
                if blob.len() / 4 != dim {
                    continue; // dimension mismatch — skip stale rows
                }
                let emb: Vec<f32> = blob
                    .chunks_exact(4)
                    .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
                    .collect();
                let mut dot = 0f32;
                for (a, b) in query_embedding.iter().zip(emb.iter()) {
                    dot += a * b;
                }
                results.push((dot as f64 * 2.0, content)); // weight semantic highly
            }
        }

        // 2. Recency/priority buckets (lower priority value = more durable).
        {
            let mut stmt = conn.prepare(
                "
                SELECT content, priority FROM (
                    SELECT 'Fact: ' || fact AS content, 0 AS priority
                    FROM facts WHERE fact NOT LIKE 'vision:%'
                    UNION ALL
                    SELECT 'Summary: ' || summary AS content, 1 AS priority FROM summaries
                    UNION ALL
                    SELECT speaker || ': ' || content AS content, 2 AS priority FROM turns
                )
                WHERE trim(content) != ''
                ORDER BY priority ASC, timestamp DESC
                LIMIT ?
                ",
            )?;
            let rows = stmt.query_map([max_items], |row| {
                let content: String = row.get(0)?;
                let priority: i64 = row.get(1)?;
                Ok((content, priority))
            })?;
            for row in rows {
                let (content, priority) = row?;
                if !safe_context_memory(&content) {
                    continue;
                }
                // Facts get a strong recency boost; recent turns a smaller one.
                let score = match priority {
                    0 => 1.0, // facts
                    1 => 0.6, // summaries
                    _ => 0.3, // turns
                };
                results.push((score, content));
            }
        }

        // Dedup by content (keep best score), then sort and return top-N.
        results.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
        let mut seen = HashSet::new();
        let mut out = Vec::with_capacity(max_items as usize);
        for (_score, content) in results {
            let key = content.trim().to_lowercase();
            if !safe_context_memory(&content) || !seen.insert(key) {
                continue;
            }
            out.push(content);
            if out.len() >= max_items as usize {
                break;
            }
        }
        Ok(out)
    }
}
