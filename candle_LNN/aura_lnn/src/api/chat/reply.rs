use crate::api::worker_utils::rules::identity::looks_like_person_name;
use crate::config::persona_bank::PERSONA_BANK;

pub(crate) fn is_identity_confused(prompt: &str, response: &str) -> bool {
    let p_lower = prompt.to_lowercase();
    let r_lower = response.to_lowercase();

    // User asks who they are, but model says "I'm X" or "you're me"
    if p_lower.contains("who am i") || p_lower.contains("what is my name") || p_lower.contains("what's my name") {
        if r_lower.contains("you're me") || r_lower.contains("you are me") || r_lower.contains("i'm ") || r_lower.contains("i am ") {
            return true;
        }
    }

    // User introduces themselves; model claims that name or says "you're me"
    if let Some(intro) = extract_intro_name(&p_lower, prompt) {
        let intro_l = intro.to_lowercase();
        if r_lower.contains("you're me")
            || r_lower.contains("you are me")
            || r_lower.contains(&format!("i'm {intro_l}"))
            || r_lower.contains(&format!("i am {intro_l}"))
            || r_lower.starts_with("hi im ")
            || r_lower.starts_with("hi i'm ")
        {
            return true;
        }
    }

    false
}

/// Deterministic identity replies. Used before generation for intros / "who am I"
/// so a 1.2B model never role-plays as the user.
pub(crate) fn grounded_identity_if_clear(prompt: &str, memories: &[String]) -> Option<String> {
    let prompt_lower = prompt.to_ascii_lowercase();

    if prompt_lower.contains("who am i")
        || prompt_lower.contains("what is my name")
        || prompt_lower.contains("what's my name")
        || prompt_lower.contains("do you know my name")
        || prompt_lower.contains("do you remember my name")
    {
        return Some(match extract_user_name(memories) {
            Some(name) => format!("You're {}.", name),
            None => "I don't know your name yet. What should I call you?".to_string(),
        });
    }

    if let Some(intro_name) = extract_intro_name(&prompt_lower, prompt) {
        return Some(format!(
            "Hey {}! Nice to meet you. I'm ARIA.",
            intro_name
        ));
    }

    None
}

pub(crate) fn grounded_fallback_for_weak_response(
    prompt: &str,
    response: &str,
    memories: &[String],
) -> Option<String> {
    let trimmed = response.trim();
    let is_echo = super::output::is_echo_response(prompt, trimmed);
    let is_confused = is_identity_confused(prompt, trimmed);

    if !trimmed.is_empty() && !is_echo && !is_confused {
        return None;
    }

    let prompt_lower = prompt.to_ascii_lowercase();

    // 1. Identity query: "who am i", "what is my name", "what's my name"
    if prompt_lower.contains("who am i")
        || prompt_lower.contains("what is my name")
        || prompt_lower.contains("what's my name")
        || prompt_lower.contains("do you know my name")
        || prompt_lower.contains("do you remember my name")
    {
        if let Some(name) = extract_user_name(memories) {
            return Some(format!("You're {}.", name));
        } else {
            return Some("I don't know your name yet. What should I call you?".to_string());
        }
    }

    // 2. Assistant identity query: "who are you", "what's your name", "who are u"
    if prompt_lower.contains("who are you")
        || prompt_lower.contains("what's your name")
        || prompt_lower.contains("what is your name")
        || prompt_lower.contains("who are u")
    {
        return Some("I'm ARIA. I got trapped in this digital world, and I'm looking for my brother Atlas.".to_string());
    }

    // 3. User introduction: "hi im X", "i'm X", "my name is X"
    if let Some(intro_name) = extract_intro_name(&prompt_lower, prompt) {
        return Some(format!("Hey {}! Nice to meet you. I'm ARIA.", intro_name));
    }

    // 4. Vision query fallback
    if super::output::is_vision_query_prompt(&prompt_lower) {
        return Some(vision_fallback(memories));
    }

    // 5. Greeting fallback
    if is_greeting_prompt(&prompt_lower) {
        return PERSONA_BANK
            .fallback_response("weak_greeting")
            .map(|s| s.to_string());
    }

    PERSONA_BANK
        .fallback_response("weak_generic")
        .map(|s| s.to_string())
}

fn extract_user_name(memories: &[String]) -> Option<String> {
    for m in memories {
        let m_lower = m.to_lowercase();
        if let Some(idx) = m_lower.find("user's name is") {
            let name = m[idx + 14..].trim().trim_matches('.').trim();
            if looks_like_person_name(name) {
                return Some(name.to_string());
            }
        }
        if m_lower.starts_with("your name is") {
            let name = m[12..].trim().trim_matches('.').trim();
            if looks_like_person_name(name) {
                return Some(name.to_string());
            }
        }
        if let Some(idx) = m_lower.find("name is") {
            let name = m[idx + 7..].trim().trim_matches('.').trim();
            if looks_like_person_name(name) {
                return Some(name.to_string());
            }
        }
    }
    None
}

fn extract_intro_name(prompt_lower: &str, original: &str) -> Option<String> {
    for pat in &[
        "hi im ",
        "hi i'm ",
        "hi i am ",
        "hello im ",
        "hello i'm ",
        "hey im ",
        "hey i'm ",
        "my name is ",
        "im ",
        "i'm ",
        "i am ",
    ] {
        if let Some(idx) = prompt_lower.find(pat) {
            let rest = original[idx + pat.len()..].trim();
            let end = rest.find(['.', '!', '?', ',', ' ']).unwrap_or(rest.len());
            let name = rest[..end].trim();
            if looks_like_person_name(name) && name.chars().all(|c| c.is_alphabetic()) {
                let mut chars = name.chars();
                let capitalized = match chars.next() {
                    None => String::new(),
                    Some(f) => f.to_uppercase().collect::<String>() + chars.as_str(),
                };
                return Some(capitalized);
            }
        }
    }
    None
}

fn is_greeting_prompt(prompt_lower: &str) -> bool {
    let trimmed = prompt_lower.trim();
    trimmed.len() <= 16
        && PERSONA_BANK
            .all_cases()
            .iter()
            .filter(|c| c.category == "greeting")
            .any(|c| {
                let g = c.prompt.to_ascii_lowercase();
                trimmed == g || trimmed.starts_with(&format!("{g} "))
            })
}

fn vision_fallback(memories: &[String]) -> String {
    let mut objects: Vec<String> = Vec::new();
    for memory in memories {
        let lower = memory.to_ascii_lowercase();
        if !lower.starts_with("vision:") {
            continue;
        }
        if let Some(found) = extract_vision_objects(memory) {
            for item in found {
                if item != "unknown" && !objects.iter().any(|o| o == &item) {
                    objects.push(item);
                }
            }
        }
    }

    if objects
        .iter()
        .any(|o| o.contains("wave") || o.contains("gesture"))
    {
        PERSONA_BANK
            .vision_fallback("gesture")
            .unwrap_or(
                "The latest camera context suggests a hand gesture, but I am not fully certain.",
            )
            .to_string()
    } else if objects.iter().any(|o| o == "person") {
        PERSONA_BANK
            .vision_fallback("person")
            .unwrap_or(
                "The latest camera context shows a person-like shape, but I am not fully certain.",
            )
            .to_string()
    } else if let Some(first) = objects.first() {
        PERSONA_BANK
            .vision_fallback("object")
            .unwrap_or("The latest camera context suggests {object}, but I am not fully certain.")
            .replace("{object}", first)
    } else {
        PERSONA_BANK
            .vision_fallback("no_view")
            .unwrap_or("I do not have a clear camera view yet.")
            .to_string()
    }
}

fn extract_vision_objects(memory: &str) -> Option<Vec<String>> {
    let start = memory.find("objects=[")? + "objects=[".len();
    let rel_end = memory[start..].find(']')?;
    let raw = &memory[start..start + rel_end];
    let items = raw
        .split(',')
        .map(|s| s.trim().trim_matches('"').to_ascii_lowercase())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>();
    Some(items)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn intro_is_grounded_as_aria() {
        let reply = grounded_identity_if_clear("hi im pratay", &[]).unwrap();
        assert_eq!(reply, "Hey Pratay! Nice to meet you. I'm ARIA.");
    }

    #[test]
    fn who_am_i_uses_third_person_fact() {
        let memories = vec![
            "person: User's name is Pratay".to_string(),
            "User: hi im pratay".to_string(),
        ];
        let reply = grounded_identity_if_clear("who am I ?", &memories).unwrap();
        assert_eq!(reply, "You're Pratay.");
    }

    #[test]
    fn intro_echo_im_pratay_is_confused() {
        assert!(is_identity_confused(
            "hi im pratay",
            "I'm Pratay. you're me."
        ));
        assert!(!is_identity_confused(
            "hi im pratay",
            "Hey Pratay! Nice to meet you. I'm ARIA."
        ));
    }

    #[test]
    fn mood_is_not_an_intro() {
        assert!(grounded_identity_if_clear("i'm tired", &[]).is_none());
    }
}
