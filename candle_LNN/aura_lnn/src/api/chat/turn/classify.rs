use crate::api::chat::is_vision_query_prompt;

pub(crate) struct PromptClass {
    pub is_vision_query: bool,
}

pub(crate) fn prepare_prompt(prompt: &str) -> (bool, bool, String) {
    let is_internal = prompt.trim().starts_with("[Internal:");
    let prompt_trimmed = prompt.trim_end();
    let is_bar =
        !is_internal && (prompt_trimmed.ends_with("[BAR]") || prompt_trimmed.ends_with("[BRIEF]"));
    let clean_prompt = if is_bar {
        let without_bar = prompt_trimmed
            .strip_suffix("[BAR]")
            .or_else(|| prompt_trimmed.strip_suffix("[BRIEF]"))
            .unwrap_or(prompt_trimmed);
        without_bar.trim_end().to_string()
    } else {
        prompt.to_string()
    };
    (is_internal, is_bar, clean_prompt)
}

pub(crate) fn classify(clean_prompt: &str, _is_internal: bool) -> PromptClass {
    let prompt_lower = clean_prompt.to_lowercase();
    let is_vision_query = is_vision_query_prompt(&prompt_lower);

    PromptClass { is_vision_query }
}
