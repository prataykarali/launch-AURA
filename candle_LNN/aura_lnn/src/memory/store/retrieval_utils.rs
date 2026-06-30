// store/retrieval_utils.rs - Tokenization and scoring helpers for retrieval.

pub(crate) fn retrieval_tokens(text: &str) -> Vec<String> {
    const STOP: &[&str] = &[
        "a", "an", "and", "are", "as", "at", "be", "but", "by", "can", "did", "do", "does", "for",
        "from", "have", "how", "i", "in", "is", "it", "me", "my", "of", "on", "or", "our", "tell",
        "that", "the", "to", "was", "what", "when", "where", "who", "why", "with", "you", "your",
    ];
    text.split(|c: char| !c.is_ascii_alphanumeric())
        .filter_map(|raw| {
            let tok = raw.trim().to_ascii_lowercase();
            if tok.len() < 2 || STOP.binary_search(&tok.as_str()).is_ok() {
                None
            } else {
                Some(tok)
            }
        })
        .collect()
}

/// Kept for reference and `search_memory`'s direct callers; the main hybrid
/// retrieval path (`search_relevant_hybrid`) now uses full IDF-BM25 instead.
#[allow(dead_code)]
pub(crate) fn lexical_retrieval_score(query_tokens: &[String], content: &str) -> f32 {
    if query_tokens.is_empty() {
        return 0.0;
    }
    let doc_tokens = retrieval_tokens(content);
    if doc_tokens.is_empty() {
        return 0.0;
    }

    let mut freq = std::collections::HashMap::<&str, usize>::new();
    for tok in &doc_tokens {
        *freq.entry(tok.as_str()).or_default() += 1;
    }

    let mut score = 0.0f32;
    let mut matched = 0usize;
    for tok in query_tokens {
        if let Some(tf) = freq.get(tok.as_str()) {
            matched += 1;
            let rarity = if tok.len() >= 5 { 0.35 } else { 0.20 };
            score += rarity * (1.0 + (*tf as f32).ln());
        }
    }

    if matched == 0 {
        return 0.0;
    }

    let coverage = matched as f32 / query_tokens.len().max(1) as f32;
    let len_norm = (doc_tokens.len() as f32 / 24.0).clamp(0.75, 2.0);
    (score / len_norm) + (coverage * 0.35)
}

pub(crate) fn normalize_for_dedup(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}
