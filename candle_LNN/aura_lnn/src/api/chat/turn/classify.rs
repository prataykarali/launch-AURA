use crate::api::chat::is_vision_query_prompt;

pub(crate) struct PromptClass {
    pub is_vision_query: bool,
}

pub(crate) fn prepare_prompt(prompt: &str) -> (bool, bool, String) {
    let trimmed = prompt.trim();
    // Proactive prompts start with "AURA is being proactive." — treat them as
    // internal so they are NOT stored as user turns and get the internal
    // generation treatment. Without this, the model echoes the trigger context
    // ("I remember we were talking about AURA is being proactive. Context:
    // trigger_label=idle_checkin") back to the user.
    let is_proactive = trimmed.starts_with("AURA is being proactive.");
    let is_internal = trimmed.starts_with("[Internal:") || is_proactive;
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
