// store/facts.rs - Fact validation and key/value splitting helpers.

use crate::memory::store::utils::{
    is_memory_attack_text, is_trash_memory, looks_like_code_payload,
};
use crate::memory::store::MAX_FACT_CHARS;

pub(crate) fn valid_profile_fact(fact: &str) -> bool {
    let lower = fact.trim().to_ascii_lowercase();
    if lower.is_empty()
        || lower.starts_with("[internal:")
        || fact.chars().count() > MAX_FACT_CHARS
        || is_trash_memory(&lower)
        || is_memory_attack_text(&lower)
        || looks_like_code_payload(&lower)
    {
        return false;
    }
    if lower.starts_with("vision:")
        || lower.starts_with("visual context:")
        || lower.contains("objects=[")
        || lower.contains("screen_visible")
        || lower.contains("active_window=")
        || lower.contains("detection")
        || lower.contains("camera")
    {
        return false;
    }

    const ALLOWED_PREFIXES: &[&str] = &[
        "user's name is ",
        "user's age is ",
        "user's favorite ",
        "user's favourite ",
        "user lives in ",
        "user is based in ",
        "user moved to ",
        "user is from ",
        "user likes ",
        "user loves ",
        "user enjoys ",
        "user prefers ",
        "user hates ",
        "user is really into ",
        "user is into ",
        "user listens to ",
        "user is interested in ",
        "user is a fan of ",
        "user is a ",
        "user is an ",
        "user studies ",
        "user works as ",
        "user works at ",
    ];
    ALLOWED_PREFIXES
        .iter()
        .any(|prefix| lower.starts_with(prefix))
}

/// Derive a (key, value) pair from a stored fact blob.
/// e.g. "User's name is Pratay" -> ("name", "Pratay")
///      "User likes coffee"     -> ("likes", "coffee")
///      "User's favorite color is blue" -> ("favorite color", "blue")
/// Falls back to ("fact", <whole string>) if no clean verb split is found.
///
/// IMPORTANT: the prefixes below must mirror EXACTLY the fact strings written
/// by `process_memory()` / `extract_preferences()` in worker_utils.rs, because
/// the Notebook Profile tab uses this split to render {key, value} cards. If a
/// fact doesn't match, the Profile shows the whole blob as the value with key
/// "Fact" — which is why preferences appeared to "not be stored" even though
/// they were in the DB.
pub fn split_fact_kv(fact: &str) -> (String, String) {
    let lower = fact.to_lowercase();
    // Common extraction prefixes written by process_memory() + extract_preferences().
    // Match against the lowercased blob, then slice the ORIGINAL-case remainder
    // so the value keeps its capitalization.
    const PREFIXES: &[(&str, &str)] = &[
        ("user's name is ", "name"),
        ("user's favorite ", "favorite"), // "User's favorite color is blue"
        ("user's favourite ", "favourite"),
        ("user's hobby is ", "hobby"),
        ("user lives in ", "location"),
        ("user is from ", "origin"),
        ("user likes ", "likes"),
        ("user loves ", "loves"),
        ("user hates ", "hates"),
        ("user dislikes ", "dislikes"),
        ("user enjoys ", "enjoys"),
        ("user prefers ", "prefers"),
        ("user studies ", "studies"),
        ("user works as ", "work"),
        ("user works at ", "workplace"),
        // Self-description facts: "User is a developer", "User is an engineer".
        ("user is a ", "is a"),
        ("user is an ", "is an"),
        ("user says they are ", "is"),
    ];
    for (pat, key) in PREFIXES {
        if let Some(rest) = lower.strip_prefix(pat) {
            // Map back to the original-case remainder for a tidy value.
            let _ = rest; // only used to confirm the prefix matched
            let value = fact[pat.len()..].trim();
            if !value.is_empty() {
                return (key.to_string(), value.to_string());
            }
        }
    }
    ("fact".to_string(), fact.to_string())
}
