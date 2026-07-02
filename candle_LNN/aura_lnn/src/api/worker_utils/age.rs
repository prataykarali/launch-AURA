/// Extract a user's age from a lowercased, whitespace-collapsed prompt.
/// Recognizes "i am X years old", "i'm X", "my age is X", etc.
/// Filters out idioms like "explain like i'm 5" that aren't real age statements.
pub(crate) fn extract_age(cleaned: &str) -> Option<u32> {
    // Idiom detection: phrases like "explain like i'm 5" are NOT age statements.
    let idioms = [
        "explain like i'm ", "explain it like i'm ", "eli5",
        "as if i were ", "as though i were ", "like i'm ",
        "pretend i'm ", "imagine i'm ", "talk to me like i'm ",
        "break it down like i'm ", "simplify it like i'm ",
        "make it simple like i'm ", "dumb it down like i'm ",
    ];
    for idiom in &idioms {
        if cleaned.contains(idiom) {
            return None;
        }
    }

    // Reject if the prompt is a question or request.
    if cleaned.starts_with("can you ") || cleaned.starts_with("could you ")
        || cleaned.starts_with("please ") || cleaned.starts_with("help me ")
        || cleaned.starts_with("tell me ") || cleaned.starts_with("show me ")
        || cleaned.starts_with("how ") || cleaned.starts_with("what ")
        || cleaned.starts_with("why ") || cleaned.starts_with("when ")
        || cleaned.starts_with("where ") || cleaned.starts_with("who ")
    {
        return None;
    }

    let anchors = ["i am ", "i'm ", "my age is ", "my age's "];

    for anchor in anchors {
        if let Some(idx) = cleaned.find(anchor) {
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
