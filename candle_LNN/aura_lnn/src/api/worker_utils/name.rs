/// Extract a user's name from a lowercased, whitespace-collapsed prompt.
/// Returns the raw name (capitalization happens in the caller) for patterns
/// like "my name is X", "i am X", "i'm X", "call me X".
type NameExtractor = fn(&str) -> Option<String>;

pub(crate) fn capture_name(cleaned: &str) -> Option<String> {
    let patterns: &[(&str, NameExtractor)] = &[
        ("my name is ", rest_to_end_of_clause),
        ("my name's ", rest_to_end_of_clause),
        ("i am called ", rest_to_end_of_clause),
        ("im called ", rest_to_end_of_clause),
        ("i'm called ", rest_to_end_of_clause),
        ("call me ", rest_to_end_of_clause),
        ("i am ", rest_to_end_of_clause),
        ("im ", rest_to_end_of_clause),
        ("i'm ", rest_to_end_of_clause),
    ];

    for (anchor, extractor) in patterns {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            if let Some(name) = extractor(rest) {
                if name.len() > 1 && name.len() <= 30 && name.chars().any(|c| c.is_alphabetic()) {
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
