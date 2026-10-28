// rules/pets.rs — Cats, dogs, and other animals
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // "I have a cat named X", "I have a dog named X"
    let animals = [
        "cat", "dog", "bird", "fish", "rabbit", "hamster", "turtle", "lizard", "snake", "parrot",
    ];

    for animal in &animals {
        // Pattern: "i have a {animal} named X"
        let anchor = format!("i have a {} named ", animal);
        if let Some(idx) = cleaned.find(&anchor) {
            let rest_lower = &cleaned[idx + anchor.len()..];
            let end = rest_lower
                .find(['.', '!', '?', ','])
                .unwrap_or(rest_lower.len());
            let name_lower = rest_lower[..end].trim();
            if name_lower.len() >= 2 && name_lower.chars().any(|c| c.is_alphabetic()) {
                let name = restore_case(name_lower, original);
                let f = format!("User has a {} named {}", animal, name);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
        }

        // Pattern: "i have an {animal} named X" (for vowel-starting animals)
        let anchor_an = format!("i have an {} named ", animal);
        if let Some(idx) = cleaned.find(&anchor_an) {
            let rest_lower = &cleaned[idx + anchor_an.len()..];
            let end = rest_lower
                .find(['.', '!', '?', ','])
                .unwrap_or(rest_lower.len());
            let name_lower = rest_lower[..end].trim();
            if name_lower.len() >= 2 && name_lower.chars().any(|c| c.is_alphabetic()) {
                let name = restore_case(name_lower, original);
                let f = format!("User has an {} named {}", animal, name);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
        }
    }

    // Generic: "i have a X" (catches pets without "named")
    for anchor in &["i have a ", "i have an ", "i've got a ", "i've got an "] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest_lower = &cleaned[idx + anchor.len()..];
            let end = rest_lower
                .find(['.', '!', '?', ','])
                .unwrap_or(rest_lower.len());
            let thing = rest_lower[..end].trim();
            // Check if it's an animal
            if let Some(animal) = animals.iter().find(|a| thing.starts_with(*a)) {
                let f = if thing.len() > animal.len() + 7
                    && thing[animal.len()..].trim().starts_with("named")
                {
                    let name_lower = thing[animal.len() + 6..].trim();
                    // Guard: require an actual name after "named" (at least 2 alpha chars)
                    if name_lower.len() < 2 || !name_lower.chars().any(|c| c.is_alphabetic()) {
                        continue;
                    }
                    format!(
                        "User has a {} named {}",
                        animal,
                        restore_case(name_lower, original)
                    )
                } else {
                    // Only extract "User has a cat" if the word IS just the animal
                    // (not "cat named" with missing name — that's incomplete)
                    if thing == *animal
                        || thing.starts_with(*animal) && thing[animal.len()..].trim().is_empty()
                    {
                        format!("User has a {}", animal)
                    } else {
                        continue;
                    }
                };
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
        let mut c = value_lower.chars();
        c.next().unwrap().to_uppercase().collect::<String>() + c.as_str()
    }
}
