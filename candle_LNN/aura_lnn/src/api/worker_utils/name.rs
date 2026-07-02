/// Extract a user's name from a lowercased, whitespace-collapsed prompt.
/// Returns the raw name for patterns like "my name is X", "call me X".
/// STRICTLY rejects emotional/statement patterns that look like names.
type NameExtractor = fn(&str) -> Option<String>;

pub(crate) fn capture_name(cleaned: &str) -> Option<String> {
    // Only use explicit name patterns — NOT "i am X" or "i'm X" which
    // match "i am feeling sad", "i'm bored", "i am 22", etc.
    let patterns: &[(&str, NameExtractor)] = &[
        ("my name is ", rest_to_end_of_clause),
        ("my name's ", rest_to_end_of_clause),
        ("i am called ", rest_to_end_of_clause),
        ("im called ", rest_to_end_of_clause),
        ("i'm called ", rest_to_end_of_clause),
        ("call me ", rest_to_end_of_clause),
        ("you can call me ", rest_to_end_of_clause),
    ];

    for (anchor, extractor) in patterns {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            if let Some(name) = extractor(rest) {
                // Reject common false positives
                let name_lower = name.to_lowercase();
                let reject = [
                    "feeling", "bored", "sad", "happy", "tired", "hungry",
                    "fine", "good", "okay", "ok", "alright", "sure",
                    "overwhelmed", "anxious", "excited", "angry",
                ];
                if reject.contains(&name_lower.as_str()) { continue; }
                // Must be alphabetic, 2-30 chars, not a number
                if name.len() > 1 && name.len() <= 30
                    && name.chars().any(|c| c.is_alphabetic())
                    && !name.chars().all(|c| c.is_ascii_digit())
                {
                    return Some(name);
                }
            }
        }
    }

    None
}

fn rest_to_end_of_clause(rest: &str) -> Option<String> {
    let end = rest.find(['.', '!', '?', ',', ' ']).unwrap_or(rest.len());
    let name = rest[..end].trim();
    if name.is_empty() {
        return None;
    }
    Some(name.to_string())
}
