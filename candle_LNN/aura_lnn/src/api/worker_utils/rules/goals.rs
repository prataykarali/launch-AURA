// rules/goals.rs — Wants, aspirations, learning
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    let anchors: &[(&str, &str)] = &[
        ("i want to learn ", "User wants to learn "),
        ("i want to ", "User wants to "),
        ("i'm learning ", "User is learning "),
        ("im learning ", "User is learning "),
        ("i am learning ", "User is learning "),
        ("i'm reading ", "User is reading "),
        ("im reading ", "User is reading "),
        ("i am reading ", "User is reading "),
        ("i'd like to learn ", "User wants to learn "),
        ("i'd like to ", "User wants to "),
        ("i would like to learn ", "User wants to learn "),
        ("i'm trying to learn ", "User wants to learn "),
        ("im trying to learn ", "User wants to learn "),
    ];

    for (anchor, fact_prefix) in anchors {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count())
            {
                let orig = restore_case(thing, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
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
        value_lower
            .split_whitespace()
            .map(|w| {
                let mut c = w.chars();
                c.next().unwrap_or(' ').to_uppercase().collect::<String>() + c.as_str()
            })
            .collect::<Vec<_>>()
            .join(" ")
    }
}
