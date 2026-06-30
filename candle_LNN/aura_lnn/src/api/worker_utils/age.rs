/// Extract a user's age from a lowercased, whitespace-collapsed prompt.
/// Recognizes "i am X years old", "i'm X", "my age is X", etc.
pub(crate) fn extract_age(cleaned: &str) -> Option<u32> {
    // Anchors must be at a WORD boundary to avoid matching "im" inside
    // words like "anime" or "him". We check that the anchor starts the
    // string OR is preceded by a space.
    let anchors = ["i am ", "i'm ", "my age is ", "my age's "];

    for anchor in anchors {
        if let Some(idx) = cleaned.find(anchor) {
            // Ensure it's at a word boundary (start of string or preceded by space)
            if idx > 0 && !cleaned.as_bytes()[idx - 1].is_ascii_whitespace() {
                continue;
            }
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',', ' ']).unwrap_or(rest.len());
            let token = rest[..end].trim();
            if let Ok(age) = token.parse::<u32>() {
                if (1..=120).contains(&age) {
                    return Some(age);
                }
            }
        }
    }

    // "X years old" fallback — most reliable pattern
    if let Some(idx) = cleaned.find(" years old") {
        let prefix = &cleaned[..idx];
        let token = prefix.split_whitespace().last()?;
        if let Ok(age) = token.parse::<u32>() {
            if (1..=120).contains(&age) {
                return Some(age);
            }
        }
    }

    None
}
