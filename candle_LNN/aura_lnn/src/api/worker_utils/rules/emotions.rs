// rules/emotions.rs — Current mood, feelings
use super::is_valid_fact;
use crate::memory::store::MemoryStore;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // "I'm feeling X", "I am feeling X", "I feel X"
    let anchors = ["i'm feeling ", "im feeling ", "i am feeling ", "i feel "];
    for anchor in &anchors {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let mood = rest[..end].trim();
            if mood.chars().any(|c| c.is_alphabetic()) && (3..=30).contains(&mood.chars().count()) {
                let orig = restore_case(mood, original);
                let f = format!("User is feeling {}", orig);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
            break;
        }
    }

    facts
}

/// Derive behavioral insights from the prompt (mood tracking, style, interests)
pub fn extract_insights(store: &MemoryStore, cleaned: &str) {
    let words: Vec<&str> = cleaned.split_whitespace().collect();
    if words.is_empty() {
        return;
    }

    let q_marks = cleaned.matches('?').count();

    // Question density
    let question_openers = [
        "what",
        "why",
        "how",
        "when",
        "where",
        "who",
        "which",
        "can you",
        "could you",
        "do you",
        "are you",
        "is it",
    ];
    let starts_with_q = question_openers.iter().any(|o| cleaned.starts_with(o));
    if q_marks >= 2 || (q_marks >= 1 && starts_with_q) {
        let _ = store.upsert_insight(
            "style",
            "User asks a lot of questions — prefers exploratory, curious conversation",
            0.1,
            "chat",
        );
    }

    // Expressiveness
    let excl = cleaned.matches('!').count();
    let caps_words = words
        .iter()
        .filter(|w| w.len() >= 3 && w.chars().all(|c| c.is_ascii_uppercase()))
        .count();
    if excl >= 2 || caps_words >= 2 {
        let _ = store.upsert_insight(
            "tone",
            "User is expressive and enthusiastic — uses exclamations and emphasis",
            0.1,
            "chat",
        );
    }

    // Self-disclosure
    let self_disclosure = [
        "i like ", "i love ", "i enjoy ", "i'm ", "im ", "i am ", "my ", "i feel ", "i work ",
        "i study ",
    ];
    if self_disclosure.iter().any(|a| cleaned.contains(a)) {
        let _ = store.upsert_insight(
            "rapport",
            "User shares personal details openly — build on what they tell you",
            0.08,
            "chat",
        );
    }

    // Mood detection
    let stress_words = [
        "stressed",
        "anxious",
        "worried",
        "nervous",
        "tired",
        "exhausted",
        "overwhelmed",
        "panic",
        "tension",
    ];
    if stress_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is feeling stressed or overwhelmed — respond with warmth and empathy",
            0.15,
            "chat",
        );
    }

    let happy_words = [
        "happy",
        "excited",
        "glad",
        "awesome",
        "great",
        "wonderful",
        "cool",
        "super",
        "fantastic",
        "amazing",
        "passed",
        "accepted",
    ];
    if happy_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is feeling positive or excited — match their energy",
            0.15,
            "chat",
        );
    }

    let sad_words = [
        "sad",
        "depressed",
        "angry",
        "frustrated",
        "annoyed",
        "mad",
        "upset",
        "down",
        "disappointed",
        "hurt",
        "lonely",
        "alone",
    ];
    if sad_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is feeling down or sad — be gentle, supportive, patient",
            0.15,
            "chat",
        );
    }
}

fn restore_case(value_lower: &str, original: &str) -> String {
    let orig_lower = original.to_lowercase();
    if let Some(pos) = orig_lower.find(value_lower) {
        original[pos..pos + value_lower.len()].to_string()
    } else {
        value_lower.to_string()
    }
}
