// rules/family.rs — Mom, dad, siblings, partner, friends, children, extended family
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // "My X's name is Y" and "My X is named Y" and "My X is Y"
    let patterns: &[(&str, &str)] = &[
        // Parents
        ("my mom's name is ", "User has mom named "),
        ("my mum's name is ", "User has mum named "),
        ("my mother's name is ", "User has mother named "),
        ("my mom is named ", "User has mom named "),
        ("my mum is named ", "User has mum named "),
        ("my mother is named ", "User has mother named "),
        ("my mom is called ", "User has mom named "),
        ("my mum is called ", "User has mum named "),
        ("my mother is called ", "User has mother named "),
        ("my mom's called ", "User has mom named "),
        ("my dad's name is ", "User has dad named "),
        ("my father's name is ", "User has father named "),
        ("my dad is named ", "User has dad named "),
        ("my father is named ", "User has father named "),
        ("my dad is called ", "User has dad named "),
        ("my father is called ", "User has father named "),
        ("my dad's called ", "User has dad named "),
        // Siblings
        ("my sister's name is ", "User has sister named "),
        ("my brother's name is ", "User has brother named "),
        ("my sister is named ", "User has sister named "),
        ("my brother is named ", "User has brother named "),
        ("my sister is called ", "User has sister named "),
        ("my brother is called ", "User has brother named "),
        ("my sister's called ", "User has sister named "),
        ("my brother's called ", "User has brother named "),
        // Grandparents
        ("my grandma's name is ", "User has grandma named "),
        ("my grandpa's name is ", "User has grandpa named "),
        ("my grandmother's name is ", "User has grandmother named "),
        ("my grandfather's name is ", "User has grandfather named "),
        ("my grandma is named ", "User has grandma named "),
        ("my grandpa is named ", "User has grandpa named "),
        // Extended family
        ("my aunt's name is ", "User has aunt named "),
        ("my uncle's name is ", "User has uncle named "),
        ("my cousin's name is ", "User has cousin named "),
        ("my niece's name is ", "User has niece named "),
        ("my nephew's name is ", "User has nephew named "),
        ("my aunt is named ", "User has aunt named "),
        ("my uncle is named ", "User has uncle named "),
        ("my cousin is named ", "User has cousin named "),
        ("my niece is named ", "User has niece named "),
        ("my nephew is named ", "User has nephew named "),
        ("my grandma is named ", "User has grandma named "),
        ("my grandpa is named ", "User has grandpa named "),
        ("my grandmother is named ", "User has grandmother named "),
        ("my grandfather is named ", "User has grandfather named "),
        // Partner
        ("my boyfriend's name is ", "User has boyfriend named "),
        ("my girlfriend's name is ", "User has girlfriend named "),
        ("my partner's name is ", "User has partner named "),
        ("my husband's name is ", "User has spouse named "),
        ("my wife's name is ", "User has spouse named "),
        ("my fiance's name is ", "User has partner named "),
        ("my fiancée's name is ", "User has partner named "),
        ("my fiancé's name is ", "User has partner named "),
        ("my boyfriend is named ", "User has boyfriend named "),
        ("my girlfriend is named ", "User has girlfriend named "),
        ("my partner is named ", "User has partner named "),
        ("my husband is named ", "User has spouse named "),
        ("my wife is named ", "User has spouse named "),
        // Friends
        ("my best friend's name is ", "User has best friend named "),
        ("my best friend is named ", "User has best friend named "),
        ("my best friend is called ", "User has best friend named "),
        ("my friend's name is ", "User has friend named "),
        ("my friend is named ", "User has friend named "),
        ("my friend is called ", "User has friend named "),
        ("my friend's called ", "User has friend named "),
        ("my roommate's name is ", "User has roommate named "),
        ("my roommate is named ", "User has roommate named "),
        // Children
        ("my son's name is ", "User has son named "),
        ("my daughter's name is ", "User has daughter named "),
        ("my son is named ", "User has son named "),
        ("my daughter is named ", "User has daughter named "),
        ("my son is called ", "User has son named "),
        ("my daughter is called ", "User has daughter named "),
        ("my baby's name is ", "User has child named "),
        ("my kid's name is ", "User has child named "),
        ("my child's name is ", "User has child named "),
    ];

    let reject = ["named", "called", "not", "dead", "alive", "gone", "here", "there", "very", "so", "really"];

    for (anchor, fact_prefix) in patterns {
        if let Some(idx) = cleaned.find(anchor) {
            let rest_lower = &cleaned[idx + anchor.len()..];
            let end = rest_lower.find(['.', '!', '?', ',']).unwrap_or(rest_lower.len());
            let name_lower = rest_lower[..end].trim();
            if name_lower.len() < 2 || name_lower.len() > 30 { continue; }
            if !name_lower.chars().any(|c| c.is_alphabetic()) { continue; }
            if reject.contains(&name_lower) { continue; }
            let name = restore_case(name_lower, original);
            let f = format!("{}{}", fact_prefix, name);
            if is_valid_fact(&f) { facts.push(f); }
        }
    }

    // Simpler patterns: "my mom is X", "my dad is X", "my sister is X"
    // Only if X is a short name (1-2 words, alphabetic)
    let simple = [
        ("my mom is ", "User has mom named "),
        ("my mum is ", "User has mum named "),
        ("my dad is ", "User has dad named "),
        ("my sister is ", "User has sister named "),
        ("my brother is ", "User has brother named "),
        ("my boyfriend is ", "User has boyfriend named "),
        ("my girlfriend is ", "User has girlfriend named "),
        ("my best friend is ", "User has best friend named "),
        ("my husband is ", "User has spouse named "),
        ("my wife is ", "User has spouse named "),
    ];
    for (anchor, fact_prefix) in &simple {
        if let Some(idx) = cleaned.find(anchor) {
            let rest_lower = &cleaned[idx + anchor.len()..];
            let end = rest_lower.find(['.', '!', '?', ',']).unwrap_or(rest_lower.len());
            let name_lower = rest_lower[..end].trim();
            let word_count = name_lower.split_whitespace().count();
            if (1..=2).contains(&word_count) && name_lower.len() >= 2 && name_lower.len() <= 30
                && name_lower.chars().any(|c| c.is_alphabetic())
                && !reject.contains(&name_lower)
                && !name_lower.starts_with("named ") && !name_lower.starts_with("called ")
                && !["named", "called", "a ", "an ", "the "].contains(&name_lower)
            {
                let words: Vec<&str> = name_lower.split_whitespace().collect();
                let word_reject = ["not", "dead", "alive", "gone", "here", "there", "very",
                    "so", "really", "a", "an", "the", "my", "is", "was", "going", "doing",
                    "feeling", "tired", "bored", "busy", "fine", "good", "ok", "okay",
                    "alright", "sure", "sorry", "stressed", "overwhelmed", "anxious",
                    "excited", "angry", "sad", "happy", "hungry"];
                if words.iter().any(|w| word_reject.contains(w)) { continue; }
                let name = restore_case(name_lower, original);
                let f = format!("{}{}", fact_prefix, name);
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
        let mut c = value_lower.chars();
        c.next().unwrap_or(' ').to_uppercase().collect::<String>() + c.as_str()
    }
}
