// rules/edge_cases.rs — Complex multi-fact, indirect, temporal, negated, quantified
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // ── Indirect location: "i grew up in X", "i was raised in X" ─────
    for (anchor, fact_prefix) in &[
        ("i grew up in ", "User is from "),
        ("i was raised in ", "User is from "),
        ("i was born in ", "User is from "),
        ("i spent my childhood in ", "User is from "),
        ("i used to live in ", "User is from "),
        ("i previously lived in ", "User is from "),
        ("i lived in ", "User is from "),
    ] {
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

    // ── Complex multi-fact: "I live in X with my cat Y" ──────────────
    // Try to extract multiple facts from one sentence
    // "i live in vancouver with my cat pixel" → location + pet
    if let Some(idx) = cleaned.find("i live in ") {
        let rest = &cleaned[idx + 10..];
        // Extract city (up to " with " or end)
        let city_end = rest
            .find(" with ")
            .unwrap_or_else(|| rest.find(['.', '!', '?', ',']).unwrap_or(rest.len()));
        let city = rest[..city_end].trim();
        if city.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&city.chars().count()) {
            let orig = restore_case(city, original);
            let f = format!("User lives in {}", orig);
            if is_valid_fact(&f) {
                facts.push(f);
            }
        }

        // Now look for "with my cat/dog named X" in the rest
        let after_with = &rest[city_end..];
        for animal in &["cat", "dog", "bird", "rabbit", "hamster", "fish", "turtle"] {
            let pat = format!("with my {} ", animal);
            if let Some(aidx) = after_with.find(&pat) {
                let name_rest = &after_with[aidx + pat.len()..];
                let name_end = name_rest
                    .find(['.', '!', '?', ','])
                    .unwrap_or(name_rest.len());
                let alt_end = name_rest.find(" and ");
                let name_end = alt_end.map(|e| e.min(name_end)).unwrap_or(name_end);
                let name = name_rest[..name_end].trim();
                if name.chars().any(|c| c.is_alphabetic()) && name.len() >= 2 {
                    // Check if it says "named X" or just "X"
                    let actual_name = if name.starts_with("named ") {
                        &name[6..]
                    } else {
                        name
                    };
                    if actual_name.chars().any(|c| c.is_alphabetic()) {
                        let orig_name = restore_case(actual_name, original);
                        let f = format!("User has a {} named {}", animal, orig_name);
                        if is_valid_fact(&f) {
                            facts.push(f);
                        }
                    }
                }
            }
        }
    }

    // ── Temporal: "i used to X" → store as interest ──────────────────
    for anchor in &[
        "i used to live in ",
        "i used to work at ",
        "i used to study ",
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count())
            {
                let orig = restore_case(thing, original);
                let f = if anchor.contains("live") {
                    format!("User is from {}", orig)
                } else if anchor.contains("work") {
                    format!("User works at {}", orig)
                } else {
                    format!("User studies {}", orig)
                };
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
        }
    }

    // ── Quantified pets: "i have two/three cats" ─────────────────────
    let number_words = [
        ("two", 2),
        ("three", 3),
        ("four", 4),
        ("five", 5),
        ("2", 2),
        ("3", 3),
        ("4", 4),
        ("5", 5),
    ];
    let animals = [
        "cats", "dogs", "birds", "fish", "rabbits", "hamsters", "turtles",
    ];
    for (num_word, num) in &number_words {
        for animal in &animals {
            let pat = format!("i have {} {}", num_word, animal);
            if cleaned.contains(&pat) {
                let f = format!("User has {} {}", num, animal);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
        }
    }

    // ── Titles: "my favorite professor is Dr. X", "my teacher is Mr. X" ─
    // Keep the title as part of the name — "Dr. Smith" is stored as-is.
    for (anchor, fact_prefix) in &[
        ("my favorite professor is ", "User's favorite professor is "),
        ("my professor is ", "User's favorite professor is "),
        ("my teacher is ", "User's favorite teacher is "),
        ("my favorite teacher is ", "User's favorite teacher is "),
        ("my boss is named ", "User has boss named "),
        ("my boss is ", "User has boss named "),
        ("my manager is named ", "User has boss named "),
        ("my manager is ", "User has boss named "),
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = find_title_name_end(rest);
            let name = rest[..end].trim();
            // Strip "named " prefix if present (from "my boss is named X")
            let name = if name.starts_with("named ") {
                name[6..].trim()
            } else {
                name
            };
            if name.chars().any(|c| c.is_alphabetic()) && name.len() >= 2 {
                let orig = restore_case(name, original);
                let f = format!("{}{}", fact_prefix, orig);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
            break;
        }
    }

    // ── "i don't have any pets" → no fact but avoid false positive ────
    // (handled by not matching — the "i have" patterns require "a/an" after)

    // ── Conditional: "i usually like X" → extract X ──────────────────
    for anchor in &[
        "i usually like ",
        "i typically like ",
        "i normally like ",
        "i mostly like ",
        "i generally like ",
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            // Cut at " but " or " sometimes " or end
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            // Also cut at " but " or " sometimes "
            let alt_end = rest.find(" but ").or_else(|| rest.find(" sometimes "));
            let end = alt_end.map(|e| e.min(end)).unwrap_or(end);
            let thing = rest[..end].trim();
            if thing.chars().any(|c| c.is_alphabetic()) && (3..=40).contains(&thing.chars().count())
            {
                let orig = restore_case(thing, original);
                let f = format!("User likes {}", orig);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
        }
    }

    // ── Health: "i'm allergic to X", "i have asthma" ─────────────────
    for (anchor, fact_prefix) in &[
        ("i'm allergic to ", "User is allergic to "),
        ("im allergic to ", "User is allergic to "),
        ("i am allergic to ", "User is allergic to "),
        ("i have asthma", "User has asthma"),
        ("i have diabetes", "User has diabetes"),
        ("i'm lactose intolerant", "User is lactose intolerant"),
        ("i'm vegan", "User is vegan"),
        ("i'm vegetarian", "User is vegetarian"),
        ("im vegan", "User is vegan"),
        ("im vegetarian", "User is vegetarian"),
        ("i am vegan", "User is vegan"),
        ("i am vegetarian", "User is vegetarian"),
    ] {
        if cleaned.contains(anchor) {
            if anchor.ends_with("to ") {
                if let Some(idx) = cleaned.find(anchor) {
                    let rest = &cleaned[idx + anchor.len()..];
                    let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
                    let thing = rest[..end].trim();
                    // Cut at " and " / " but " / " so " to avoid grabbing extra clauses
                    let thing = thing
                        .split(" and ")
                        .next()
                        .unwrap_or(thing)
                        .split(" but ")
                        .next()
                        .unwrap_or(thing)
                        .split(" so ")
                        .next()
                        .unwrap_or(thing)
                        .trim();
                    if thing.chars().any(|c| c.is_alphabetic()) && thing.len() >= 2 {
                        let orig = restore_case(thing, original);
                        let f = format!("{}{}", fact_prefix, orig);
                        if is_valid_fact(&f) {
                            facts.push(f);
                        }
                    }
                }
            } else {
                let f = fact_prefix.to_string();
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

/// Find the end of a name that may contain title periods (Dr., Mr., Mrs., Ms., Prof.)
/// so "dr. smith" is captured whole instead of being cut at the "dr." period.
fn find_title_name_end(rest: &str) -> usize {
    const TITLES: &[&str] = &["dr", "mr", "mrs", "ms", "prof"];
    let bytes = rest.as_bytes();
    let mut search_from = 0;
    loop {
        let end = rest[search_from..]
            .find(['.', '!', '?', ','])
            .map(|pos| search_from + pos)
            .unwrap_or(rest.len());
        if end < rest.len() && bytes[end] == b'.' {
            let before = &rest[search_from..end];
            if TITLES.contains(&before) {
                search_from = end + 1;
                while search_from < rest.len() && bytes[search_from] == b' ' {
                    search_from += 1;
                }
                continue;
            }
        }
        return end;
    }
}
