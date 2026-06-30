use crate::memory::store;

pub(crate) fn cap_memory_item(s: &str, max_chars: usize) -> String {
    let s = s.trim();
    if s.chars().count() <= max_chars {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max_chars).collect();
    if let Some(idx) = out.rfind(|c: char| c.is_whitespace()) {
        out.truncate(idx);
    }
    out.push_str("...");
    out
}

pub(crate) fn clean_model_output_prefix(text: &str) -> String {
    let mut cleaned = store::strip_speaker_prefix(text);
    loop {
        let trimmed = cleaned.trim_start();
        let lower = trimmed.to_ascii_lowercase();
        let Some(prefix) = [
            "<|think|>",
            "<|/think|>",
            "aura bar instruction: answer directly in 1 short sentence.",
            "aura bar instruction: answer directly",
            "answer directly in 1 short sentence.",
            "action: respond_directly()",
            "action: respond_directly",
            "[internal:",
            "internal:",
            "observation:",
        ]
        .iter()
        .find(|prefix| lower.starts_with(**prefix)) else {
            break;
        };
        // For [internal: ...] blocks, skip to the closing bracket if present
        if lower.starts_with("[internal:") {
            if let Some(end) = trimmed.find(']') {
                cleaned = trimmed[end + 1..].trim_start().to_string();
            } else {
                cleaned = trimmed[prefix.len()..].trim_start().to_string();
            }
        } else {
            cleaned = trimmed[prefix.len()..].trim_start().to_string();
        }
    }
    cleaned = strip_think_blocks(&cleaned);
    cleaned = strip_action_lines(&cleaned);
    cleaned
}

/// Remove paired <|think|>...<|/think|> blocks from anywhere in the response.
pub(crate) fn strip_think_blocks(text: &str) -> String {
    let mut result = text.to_string();
    loop {
        let lower = result.to_ascii_lowercase();
        let mut found = false;
        if let Some(start) = lower.find("<|think|>") {
            let after_open = start + "<|think|>".len();
            if let Some(rel_end) = lower[after_open..].find("<|/think|>") {
                let end = after_open + rel_end + "<|/think|>".len();
                result = format!(
                    "{}{}",
                    result[..start].trim_end(),
                    result[end..].trim_start()
                );
                found = true;
            } else {
                // Unclosed think block — strip from here to end of string.
                result = result[..start].trim_end().to_string();
                found = true;
            }
        }
        if !found {
            break;
        }
    }
    result
}

/// Remove trailing "Action: ..." lines that the model might append after its reply.
pub(crate) fn strip_action_lines(text: &str) -> String {
    let lines: Vec<&str> = text.lines().collect();
    let mut end = lines.len();
    while end > 0 {
        let lower = lines[end - 1].trim().to_ascii_lowercase();
        if lower.starts_with("action:")
            || lower.starts_with("observation:")
            || lower.starts_with("[internal:")
            || lower.is_empty()
        {
            end -= 1;
        } else {
            break;
        }
    }
    lines[..end].join("\n")
}

pub(crate) fn is_vision_query_prompt(prompt_lower: &str) -> bool {
    [
        "see",
        "look",
        "watch",
        "camera",
        "surroundings",
        "environment",
        "room",
        "desk",
        "wearing",
        "carrying",
        "wave",
        "waving",
        "hand",
        "gesture",
        "action",
        "doing",
    ]
    .iter()
    .any(|w| prompt_lower.contains(w))
}

pub(crate) fn is_echo_response(prompt: &str, response: &str) -> bool {
    let p = normalize_for_echo(prompt);
    let r = normalize_for_echo(response);
    !p.is_empty() && (p == r || r.starts_with(&p) || p.starts_with(&r))
}

pub(crate) fn normalize_for_echo(text: &str) -> String {
    text.chars()
        .filter_map(|c| {
            if c.is_ascii_alphanumeric() {
                Some(c.to_ascii_lowercase())
            } else if c.is_whitespace() {
                Some(' ')
            } else {
                None
            }
        })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}
