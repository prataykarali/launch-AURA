// rules/location.rs — City, country, origin
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    let anchors: &[(&str, &str)] = &[
        ("i live in ", "User lives in "),
        ("i'm based in ", "User is based in "),
        ("im based in ", "User is based in "),
        ("i moved to ", "User moved to "),
        ("i'm from ", "User is from "),
        ("im from ", "User is from "),
        ("i am from ", "User is from "),
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
