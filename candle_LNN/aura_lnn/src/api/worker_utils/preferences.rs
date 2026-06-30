/// Pull a small core set of first-person self-disclosures out of a lowercased,
/// whitespace-collapsed prompt. Returns durable fact strings of the form
/// "User <likes/loves/is/...> <thing>".
///
/// This list is intentionally short — we do not try to hardcode every possible
/// way a person might express a preference. The common patterns (like, love,
/// favorite, location, identity) are lifted into the explicit `facts` table for
/// reliable recall; everything else is left in `vec_memory` and retrieved by
/// semantic search when the user asks about it.
pub(crate) fn extract_preferences(cleaned: &str) -> Vec<String> {
    if cleaned.starts_with("[internal:") {
        return Vec::new();
    }
    let mut out: Vec<String> = Vec::new();

    // (anchor, verb-for-fact). verb is the natural-language form used in the
    // stored fact ("User likes ...", "User is ...").
    let anchors: &[(&str, &str)] = &[
        // Core preferences
        ("i like ", "likes"),
        ("i love ", "loves"),
        ("i enjoy ", "enjoys"),
        ("i prefer ", "prefers"),
        ("i hate ", "hates"),
        ("my favorite ", "has favorite"), // "my favorite food is X"
        ("my favourite ", "has favourite"),
        // Location
        ("i live in ", "lives in"),
        ("i'm from ", "is from"),
        ("im from ", "is from"),
        ("i am from ", "is from"),
        // Core identity-adjacent self-descriptions
        ("i'm a ", "is a"),
        ("im a ", "is a"),
        ("i am a ", "is a"),
        ("i'm an ", "is an"),
        ("im an ", "is an"),
        ("i am an ", "is an"),
        ("i study ", "studies"),
        ("i work as ", "works as"),
        ("i work at ", "works at"),
    ];

    for (anchor, verb) in anchors {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            // Cut at the first sentence/clause boundary.
            let clause_end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let mut thing = rest[..clause_end].trim().to_string();
            // Strip a leading article/filler so the fact reads cleanly.
            for prefix in ["the ", "a ", "an ", "to ", "eating ", "drinking ", "going "] {
                if let Some(stripped) = thing.strip_prefix(prefix) {
                    thing = stripped.trim().to_string();
                    break;
                }
            }
            // Sanity: need at least one alphabetic char and not too long.
            let alpha = thing.chars().any(|c| c.is_alphabetic());
            if alpha && (3..=40).contains(&thing.chars().count()) {
                // Special-case "my favorite" → "User's favorite <X> is <thing>"
                // where X is the category captured between the anchor and "is".
                let fact = if matches!(*verb, "has favorite" | "has favourite") {
                    // Reconstruct: anchor was "my favorite ", the category is
                    // everything up to " is " in `rest`, thing is after " is ".
                    if let Some(is_idx) = rest.find(" is ") {
                        let category = rest[..is_idx].trim();
                        let value = rest[is_idx + 4..]
                            .find(['.', '!', '?', ','])
                            .map(|e| &rest[is_idx + 4..is_idx + 4 + e])
                            .unwrap_or(&rest[is_idx + 4..])
                            .trim();
                        if value.chars().any(|c| c.is_alphabetic()) {
                            format!("User's favorite {} is {}", category, value)
                        } else {
                            continue;
                        }
                    } else {
                        continue;
                    }
                } else {
                    format!("User {} {}", verb, thing)
                };
                out.push(fact);
            }
        }
    }

    out
}
