use crate::config::persona_bank::{PersonaCase, PERSONA_BANK};
use crate::memory::BgeTextEmbedder;
use flutter_rust_bridge::frb;
use std::sync::OnceLock;

/// Global semantic index for persona examples.  Initialized once when the
/// embedder becomes available; subsequent chat turns reuse the cached vectors.
#[frb(ignore)]
static PERSONA_INDEX: OnceLock<PersonaIndex> = OnceLock::new();

#[frb(ignore)]
pub struct PersonaIndex {
    cases: Vec<PersonaCase>,
    vectors: Vec<Vec<f32>>,
}

impl PersonaIndex {
    /// Build the index by embedding every persona case with the shared embedder.
    /// Called once from engine initialization.
    pub fn build(
        embedder: &BgeTextEmbedder,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let mut cases = Vec::new();
        let mut vectors = Vec::new();
        for case in PERSONA_BANK.all_cases() {
            let text = format!("{} {} {}", case.prompt, case.category, case.expected_tone);
            let vec = embedder.embed_passage(&text)?;
            cases.push(case.clone());
            vectors.push(vec);
        }
        Ok(PersonaIndex { cases, vectors })
    }

    /// Find the top-k most similar persona cases to the query embedding and
    /// return them formatted as few-shot "User: ... AURA: ..." lines.
    pub fn retrieve_examples(&self, query: &[f32], k: usize) -> Vec<String> {
        let k = k.min(self.cases.len());
        if k == 0 || query.is_empty() {
            return Vec::new();
        }

        let mut scored: Vec<(usize, f32)> = self
            .vectors
            .iter()
            .enumerate()
            .map(|(i, vec)| (i, cosine_similarity(query, vec)))
            .collect();
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        scored
            .into_iter()
            .take(k)
            .map(|(i, _)| format_example(&self.cases[i]))
            .collect()
    }

    /// Check if the query is a memory-recall query (matches a memory_recall
    /// persona case with cosine >= threshold). Returns the best matching
    /// case's reference response if it's a memory-recall match.
    pub fn match_memory_recall(&self, query: &[f32], threshold: f32) -> Option<String> {
        if query.is_empty() || self.cases.is_empty() {
            return None;
        }
        let mut best: Option<(usize, f32)> = None;
        for (i, vec) in self.vectors.iter().enumerate() {
            if self.cases[i].category != "memory_recall" {
                continue;
            }
            let sim = cosine_similarity(query, vec);
            if sim >= threshold && (best.is_none() || sim > best.unwrap().1) {
                best = Some((i, sim));
            }
        }
        best.map(|(i, _)| self.cases[i].reference_response.clone())
    }
}

fn format_example(case: &PersonaCase) -> String {
    format!("User: {}\nAURA: {}", case.prompt, case.reference_response)
}

fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let mut dot = 0.0;
    let mut a_norm = 0.0;
    let mut b_norm = 0.0;
    for (x, y) in a.iter().zip(b.iter()) {
        dot += x * y;
        a_norm += x * x;
        b_norm += y * y;
    }
    let denom = (a_norm * b_norm).sqrt();
    if denom == 0.0 {
        0.0
    } else {
        dot / denom
    }
}

/// Initialize the global persona index.  Safe to call multiple times; only the
/// first call builds the index.  Internal use only — not exposed to Flutter.
#[frb(ignore)]
pub fn init_persona_index(
    embedder: &BgeTextEmbedder,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if PERSONA_INDEX.get().is_some() {
        return Ok(());
    }
    let index = PersonaIndex::build(embedder)?;
    let _ = PERSONA_INDEX.set(index);
    Ok(())
}

/// Retrieve top-k examples from the global index, if it has been initialized.
pub fn retrieve_persona_examples(query: &[f32], k: usize) -> Vec<String> {
    PERSONA_INDEX
        .get()
        .map(|idx| idx.retrieve_examples(query, k))
        .unwrap_or_default()
}

/// Check if the query is a memory-recall query. If the query embedding
/// matches a memory_recall persona case with cosine >= threshold, return
/// that case's reference response. Used to fast-path memory queries WITHOUT
/// running the full LLM — the retrieved memory is appended instead.
pub fn match_memory_recall(query: &[f32], threshold: f32) -> Option<String> {
    PERSONA_INDEX
        .get()
        .and_then(|idx| idx.match_memory_recall(query, threshold))
}

/// Return a reference to the global index, if it has been initialized.
#[allow(dead_code)]
#[frb(ignore)]
pub fn persona_index() -> Option<&'static PersonaIndex> {
    PERSONA_INDEX.get()
}
