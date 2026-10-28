use crate::api::chat::turn::extract_user_from_turn;

pub fn build_memory_prefix(memories: &[String]) -> Option<String> {
    let mut facts: Vec<String> = Vec::new();

    for m in memories {
        let lower = m.to_lowercase();
        if is_turn_line(&lower) || is_note_line(&lower) {
            continue;
        }
        if lower.starts_with("summary:") {
            continue;
        }
        if lower.contains("vision:")
            || lower.contains("objects=[")
            || lower.contains("screen_visible")
            || lower.contains("camera")
        {
            continue;
        }
        if lower.contains("schedule request:") || lower.contains("schedule:") {
            continue;
        }

        let content = fact_as_third_person(m.trim());
        if content.is_empty() {
            continue;
        }

        let c = if content.chars().count() > 80 {
            content
                .chars()
                .take(80)
                .collect::<String>()
                .trim()
                .to_string()
        } else {
            content.trim().to_string()
        };

        if !facts.iter().any(|f| f == &c) {
            facts.push(c);
        }
        if facts.len() >= 4 {
            break;
        }
    }

    if facts.is_empty() {
        return None;
    }
    let joined = facts.join("; ");
    let joined = if joined.chars().count() > 200 {
        joined.chars().take(200).collect()
    } else {
        joined
    };
    Some(format!("[KNOW: {joined}]\n"))
}

/// Build a compact conversation recap from recent turns so the model has
/// multi-turn context even after a KV-cache reset.
///
/// Format: `[Recent chat:\nUser: X\nARIA: Y\nUser: Z\nARIA: W\n]`
/// Each turn is capped to ~100 chars so the recap stays compact.
pub fn build_conversation_recap(memories: &[String]) -> Option<String> {
    let mut turns: Vec<(String, String)> = Vec::new();

    for m in memories {
        let lower = m.to_lowercase();
        if lower.starts_with("user:") {
            let content = extract_user_from_turn(m);
            if !content.is_empty() {
                let clipped: String = content.chars().take(100).collect();
                turns.push(("User".to_string(), clipped.trim().to_string()));
            }
        } else if lower.starts_with("aria:")
            || lower.starts_with("aura:")
            || lower.starts_with("assistant:")
        {
            let content = if lower.starts_with("aria:") || lower.starts_with("aura:") {
                m[5..].trim().to_string()
            } else {
                m[10..].trim().to_string()
            };
            if !content.is_empty() {
                let clipped: String = content.chars().take(100).collect();
                turns.push(("ARIA".to_string(), clipped.trim().to_string()));
            }
        }
    }

    if turns.is_empty() {
        return None;
    }

    let start = turns.len().saturating_sub(6);
    let recent = &turns[start..];

    let mut lines = Vec::new();
    for (speaker, content) in recent {
        lines.push(format!("{speaker}: {content}"));
    }

    Some(format!("[Recent chat:\n{}\n]\n", lines.join("\n")))
}

fn is_turn_line(lower: &str) -> bool {
    lower.starts_with("user:")
        || lower.starts_with("aria:")
        || lower.starts_with("aura:")
        || lower.starts_with("assistant:")
}

fn is_note_line(lower: &str) -> bool {
    lower.starts_with("note —")
        || lower.starts_with("note -")
        || lower.starts_with("note:")
        || lower.starts_with("kind: note")
}

/// Keep facts attributed to the user. Never flip I/my → you/your: that rewrite
/// sits inside `<|im_start|>user` and the model reads "your name is X" as its own.
fn fact_as_third_person(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let lower = trimmed.to_lowercase();
    if let Some(idx) = trimmed.find(": ") {
        let prefix = lower[..idx].trim();
        if prefix.chars().all(|c| c.is_ascii_alphabetic()) && prefix.len() <= 12 {
            let rest = trimmed[idx + 2..].trim();
            if !rest.is_empty() {
                return rest.to_string();
            }
        }
    }
    trimmed.to_string()
}

pub fn build_recall_prefill(prompt: &str, memories: &[String]) -> Option<String> {
    let lower = prompt.to_lowercase();
    let is_name_query = lower.contains("what is my name")
        || lower.contains("what's my name")
        || lower.contains("who am i")
        || lower.contains("do you remember my name")
        || lower.contains("do you know my name");
    if !is_name_query {
        return None;
    }

    for m in memories {
        let m_lower = m.to_lowercase();
        if let Some(idx) = m_lower.find("user's name is") {
            let name = m[idx + 14..].trim();
            if !name.is_empty() {
                return Some(format!("Your name is {}.", name));
            }
        }
        if m_lower.starts_with("user ") && m_lower.contains("name is") {
            if let Some(idx) = m_lower.find("name is") {
                let name = m[idx + 7..].trim();
                if !name.is_empty() {
                    return Some(format!("Your name is {}.", name));
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn know_keeps_third_person_and_skips_turns() {
        let memories = [
            "User: hi im pratay".to_string(),
            "User's name is Pratay".to_string(),
            "person: User's name is Pratay".to_string(),
            "ARIA: hey there".to_string(),
            "Note — homework: finish calc".to_string(),
            "User has a cat named Mochi".to_string(),
        ];
        let prefix = build_memory_prefix(&memories).expect("facts should inject");
        assert!(
            prefix.contains("User's name is Pratay"),
            "prefix={prefix}"
        );
        assert!(
            prefix.contains("User has a cat named Mochi"),
            "prefix={prefix}"
        );
        let lower = prefix.to_lowercase();
        assert!(!lower.contains("you're pratay"), "prefix={prefix}");
        assert!(!lower.contains("your name is"), "prefix={prefix}");
        assert!(!prefix.contains("hi im"), "prefix={prefix}");
        assert!(!prefix.contains("homework"), "prefix={prefix}");
    }

    #[test]
    fn recap_keeps_speaker_labels() {
        let memories = [
            "User: earlier thing".to_string(),
            "ARIA: ok".to_string(),
            "User: hi im pratay".to_string(),
        ];
        let recap = build_conversation_recap(&memories).expect("recap");
        assert!(recap.contains("User: earlier thing"), "recap={recap}");
        assert!(recap.contains("User: hi im pratay"), "recap={recap}");
        assert!(recap.contains("ARIA: ok"), "recap={recap}");
    }
}
