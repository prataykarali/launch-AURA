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

pub(crate) fn normalize_for_dedup(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}
