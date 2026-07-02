// rules/preferences.rs — Likes, loves, hates, favorites, hobbies, interests
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // ── Core preferences ─────────────────────────────────────────────
    let anchors: &[(&str, &str)] = &[
        ("i like ", "User likes "),
        ("i love ", "User loves "),
        ("i enjoy ", "User enjoys "),
        ("i prefer ", "User prefers "),
        ("i hate ", "User hates "),
        ("i dislike ", "User dislikes "),
        ("i don't like ", "User dislikes "),
        ("i dont like ", "User dislikes "),
        ("i'm really into ", "User is really into "),
        ("im really into ", "User is really into "),
        ("i am really into ", "User is really into "),
        ("i'm into ", "User is into "),
        ("im into ", "User is into "),
        ("i am into ", "User is into "),
        ("i'm passionate about ", "User is interested in "),
        ("im passionate about ", "User is interested in "),
        ("i am passionate about ", "User is interested in "),
        ("i'm obsessed with ", "User is really into "),
        ("im obsessed with ", "User is really into "),
        ("i am obsessed with ", "User is really into "),
        ("i'm a fan of ", "User is a fan of "),
        ("im a fan of ", "User is a fan of "),
        ("i am a fan of ", "User is a fan of "),
        ("i adore ", "User loves "),
        ("i'm fond of ", "User likes "),
        ("im fond of ", "User likes "),
        ("i am fond of ", "User likes "),
        ("i can't stand ", "User hates "),
        ("i cant stand ", "User hates "),
        ("i'm not a fan of ", "User dislikes "),
        ("im not a fan of ", "User dislikes "),
    ];

    for (anchor, fact_prefix) in anchors {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let clause_end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let mut thing = rest[..clause_end].trim().to_string();
            for prefix in &["the ", "a ", "an ", "to ", "eating ", "drinking ", "going ",
                           "playing ", "listening to ", "watching ", "reading ", "doing "] {
                if let Some(s) = thing.strip_prefix(prefix) { thing = s.trim().to_string(); break; }
            }
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=50).contains(&thing.chars().count()) {
                let orig = restore_case(&thing, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    // ── Favorites: "my favorite X is Y" ──────────────────────────────
    // Skip "professor"/"teacher" — edge_cases.rs handles those with
    // title-aware extraction (Dr., Mr., etc.) to avoid period-cut duplicates.
    for anchor in &["my favorite ", "my favourite "] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            if let Some(is_idx) = rest.find(" is ") {
                let category = rest[..is_idx].trim();
                if category == "professor" || category == "teacher" { continue; }
                let value_lower = rest[is_idx + 4..]
                    .find(['.', '!', '?', ','])
                    .map(|e| &rest[is_idx + 4..is_idx + 4 + e])
                    .unwrap_or(&rest[is_idx + 4..])
                    .trim();
                if value_lower.chars().any(|c| c.is_alphabetic()) && value_lower.len() >= 2 {
                    let value = restore_case(value_lower, original);
                    let f = format!("User's favorite {} is {}", category, value);
                    if is_valid_fact(&f) { facts.push(f); }
                }
            }
        }
    }

    // ── Music: "i listen to X", "my favorite band is X" ──────────────
    for (anchor, fact_prefix) in &[
        ("i listen to ", "User listens to "),
        ("i'm listening to ", "User listens to "),
        ("im listening to ", "User listens to "),
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count()) {
                let orig = restore_case(thing, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    // ── Hobbies: "my hobby is X", "i play X" ─────────────────────────
    for (anchor, fact_prefix) in &[
        ("my hobby is ", "User's hobby is "),
        ("my hobbies are ", "User's hobby is "),
        ("i play ", "User likes playing "),
        ("i'm learning to play ", "User is learning "),
        ("im learning to play ", "User is learning "),
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count()) {
                let orig = restore_case(thing, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    // ── Entertainment: "i watch X", "i read X" ───────────────────────
    for (anchor, fact_prefix) in &[
        ("i watch ", "User likes watching "),
        ("i read ", "User likes reading "),
        ("i'm reading ", "User is reading "),
        ("im reading ", "User is reading "),
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count()) {
                let orig = restore_case(thing, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    facts
}

fn restore_case(value_lower: &str, original: &str) -> String {
    let orig_lower = original.to_lowercase();
    if let Some(pos) = orig_lower.find(value_lower) {
        original[pos..pos + value_lower.len()].to_string()
    } else {
        value_lower.split_whitespace().map(|w| {
            let mut c = w.chars();
            c.next().unwrap_or(' ').to_uppercase().collect::<String>() + c.as_str()
        }).collect::<Vec<_>>().join(" ")
    }
}
