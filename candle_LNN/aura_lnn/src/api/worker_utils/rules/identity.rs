// rules/identity.rs — Name, age, gender, pronouns, occupation, education
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // ── Name (explicit patterns only) ────────────────────────────────
    if let Some(name) = extract_name(cleaned, original) {
        let f = format!("User's name is {}", name);
        if is_valid_fact(&f) { facts.push(f); }
    }

    // ── Age ──────────────────────────────────────────────────────────
    if let Some(age) = extract_age(cleaned) {
        let f = format!("User's age is {}", age);
        if is_valid_fact(&f) { facts.push(f); }
    }

    // ── Pronouns ─────────────────────────────────────────────────────
    for anchor in &["my pronouns are ", "my pronoun is "] {
        if let Some(rest) = cleaned.find(anchor).map(|i| &cleaned[i + anchor.len()..]) {
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let val = rest[..end].trim();
            if val.len() >= 2 && val.chars().any(|c| c.is_alphabetic())
                && !val.starts_with("to ")  // reject "to live", "to work" false positives
            {
                let f = format!("User's pronouns are {}", val);
                if is_valid_fact(&f) { facts.push(f); }
                break;
            }
        }
    }

    // ── Gender ───────────────────────────────────────────────────────
    for (anchor, fact) in &[
        ("i'm a woman", "User is a woman"),
        ("im a woman", "User is a woman"),
        ("i'm a man", "User is a man"),
        ("im a man", "User is a man"),
        ("i'm a boy", "User is a boy"),
        ("im a boy", "User is a boy"),
        ("i'm a girl", "User is a girl"),
        ("im a girl", "User is a girl"),
        ("i am non-binary", "User is non-binary"),
        ("i'm non-binary", "User is non-binary"),
        ("im non-binary", "User is non-binary"),
        ("i am transgender", "User is transgender"),
        ("i'm transgender", "User is transgender"),
    ] {
        if cleaned.contains(anchor) {
            if is_valid_fact(fact) { facts.push(fact.to_string()); }
        }
    }

    // ── Occupation / Study ───────────────────────────────────────────
    for (anchor, verb) in &[
        ("i study ", "studies"), ("i'm studying ", "studies"), ("im studying ", "studies"),
        ("i am studying ", "studies"), ("i major in ", "studies"),
        ("i'm majoring in ", "studies"), ("im majoring in ", "studies"),
        ("i work as ", "works as"), ("i'm working as ", "works as"), ("im working as ", "works as"),
        ("i work at ", "works at"), ("i'm working at ", "works at"), ("im working at ", "works at"),
        ("i am a ", "is a"), ("i'm a ", "is a"), ("im a ", "is a"),
        ("i am an ", "is an"), ("i'm an ", "is an"), ("im an ", "is an"),
        ("i am the ", "is the"), ("i'm the ", "is the"), ("im the ", "is the"),
        ("i'm the ceo of ", "is the CEO of"), ("im the ceo of ", "is the CEO of"),
        ("i'm the founder of ", "is the founder of"), ("im the founder of ", "is the founder of"),
        ("i'm the director of ", "is the director of"), ("im the director of ", "is the director of"),
        ("i'm the head of ", "is the head of"), ("im the head of ", "is the head of"),
        ("i run ", "runs"), ("i'm running ", "runs"), ("im running ", "runs"),
        ("i go to ", "studies at"), ("i attend ", "studies at"),
        ("i'm a student at ", "is a student at"), ("im a student at ", "is a student at"),
        ("i teach ", "teaches"), ("i'm a teacher", "is a teacher"),
    ] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let mut thing = rest[..end].trim().to_string();
            for prefix in &["the ", "a ", "an ", "to ", "eating ", "drinking ", "going ", "as ", "at "] {
                if let Some(s) = thing.strip_prefix(prefix) { thing = s.trim().to_string(); break; }
            }
            if thing.chars().any(|c| c.is_alphabetic()) && (2..=50).contains(&thing.chars().count()) {
                let orig = find_in_original(&thing, original).unwrap_or_else(|| capitalize(&thing));
                let f = format!("User {} {}", verb, orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    // ── Languages spoken ─────────────────────────────────────────────
    for anchor in &["i speak ", "i'm fluent in ", "im fluent in ", "i am fluent in ", "i know "] {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let lang = rest[..end].trim();
            if lang.chars().any(|c| c.is_alphabetic()) && (3..=20).contains(&lang.chars().count()) {
                let orig = find_in_original(lang, original).unwrap_or_else(|| capitalize(lang));
                let f = format!("User is a fan of {}", orig);
                if is_valid_fact(&f) { facts.push(f); }
            }
        }
    }

    facts
}

fn extract_name(cleaned: &str, original: &str) -> Option<String> {
    let patterns = [
        "my name is ", "my name's ", "i am called ", "im called ",
        "i'm called ", "call me ", "you can call me ",
        "my real name is ", "my full name is ",
        "people call me ", "everyone calls me ", "my friends call me ",
    ];
    let reject = [
        "feeling", "bored", "sad", "happy", "tired", "hungry", "fine",
        "good", "okay", "ok", "alright", "sure", "overwhelmed", "anxious",
        "excited", "angry", "stressed", "sorry", "busy", "done", "back",
        "here", "there", "lost", "not", "a ", "an ", "the ", "my ",
    ];
    for pat in &patterns {
        if let Some(idx) = cleaned.find(pat) {
            let rest_lower = &cleaned[idx + pat.len()..];
            let end = find_name_end(rest_lower);
            let name_lower = rest_lower[..end].trim();
            if name_lower.len() <= 1 || name_lower.len() > 30 { continue; }
            if reject.iter().any(|r| name_lower == *r || name_lower.starts_with(r)) { continue; }
            if !name_lower.chars().any(|c| c.is_alphabetic()) { continue; }
            if name_lower.chars().all(|c| c.is_ascii_digit()) { continue; }
            return Some(find_in_original(name_lower, original).unwrap_or_else(|| capitalize(name_lower)));
        }
    }
    None
}

/// Find the end of a name, skipping title periods (Dr., Mr., Mrs., Ms., Prof.)
/// so that "Dr. Smith" is captured as a whole instead of being cut at "Dr".
fn find_name_end(rest: &str) -> usize {
    const TITLES: &[&str] = &["dr", "mr", "mrs", "ms", "prof"];
    let bytes = rest.as_bytes();
    let mut search_from = 0;
    loop {
        let end = rest[search_from..]
            .find(['.', '!', '?', ',', ' '])
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

fn extract_age(cleaned: &str) -> Option<u32> {
    // Idiom detection: phrases like "explain like i'm 5", "as if i were 10"
    // are NOT real age statements. Filter them out before extracting.
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

    // Also reject age extraction if the prompt is a question or request
    // (not a statement about oneself).
    if cleaned.starts_with("can you ") || cleaned.starts_with("could you ")
        || cleaned.starts_with("please ") || cleaned.starts_with("help me ")
        || cleaned.starts_with("tell me ") || cleaned.starts_with("show me ")
        || cleaned.starts_with("how ") || cleaned.starts_with("what ")
        || cleaned.starts_with("why ") || cleaned.starts_with("when ")
        || cleaned.starts_with("where ") || cleaned.starts_with("who ")
    {
        return None;
    }

    for anchor in &["i am ", "i'm ", "my age is ", "my age's ", "i'm currently ", "im currently "] {
        if let Some(idx) = cleaned.find(anchor) {
            if idx > 0 && !cleaned.as_bytes()[idx - 1].is_ascii_whitespace() { continue; }
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',', ' ']).unwrap_or(rest.len());
            if let Ok(age) = rest[..end].trim().parse::<u32>() {
                if (1..=120).contains(&age) { return Some(age); }
            }
        }
    }
    if let Some(idx) = cleaned.find(" years old") {
        let token = cleaned[..idx].split_whitespace().last()?;
        if let Ok(age) = token.parse::<u32>() {
            if (1..=120).contains(&age) { return Some(age); }
        }
    }
    None
}

fn find_in_original(value_lower: &str, original: &str) -> Option<String> {
    let orig_lower = original.to_lowercase();
    orig_lower.find(value_lower).map(|pos| original[pos..pos + value_lower.len()].to_string())
}

fn capitalize(s: &str) -> String {
    s.split_whitespace().map(|w| {
        let mut c = w.chars();
        c.next().unwrap_or(' ').to_uppercase().collect::<String>() + c.as_str()
    }).collect::<Vec<_>>().join(" ")
}
