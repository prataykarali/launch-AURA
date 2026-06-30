use crate::config::persona_bank::PERSONA_BANK;

pub(crate) fn grounded_fallback_for_weak_response(
    prompt: &str,
    response: &str,
    memories: &[String],
) -> Option<String> {
    let trimmed = response.trim();
    if !trimmed.is_empty() && !super::output::is_echo_response(prompt, trimmed) {
        return None;
    }

    let prompt_lower = prompt.to_ascii_lowercase();
    if super::output::is_vision_query_prompt(&prompt_lower) {
        return Some(vision_fallback(memories));
    }

    if is_greeting_prompt(&prompt_lower) {
        return PERSONA_BANK
            .fallback_response("weak_greeting")
            .map(|s| s.to_string());
    }

    PERSONA_BANK
        .fallback_response("weak_generic")
        .map(|s| s.to_string())
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

