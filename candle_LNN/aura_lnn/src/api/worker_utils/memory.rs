use crate::memory::store::MemoryStore;

/// Post-turn memory processing.
///
/// NO hardcoded extractors (name, age, preferences, insights) — memory is
/// entirely natural. The conversation turn itself is stored in vec_memory
/// by the caller via `store_embed("User: ...\nAURA: ...")`. The embedder
/// retrieves it later via cosine similarity when the user references a past
/// topic ("let's continue studying", "what did we talk about", etc.).
///
/// The only thing we do here is maintain a rolling conversation summary
/// (for the notebook tab) and extract schedule notes (a feature, not memory).
pub(crate) fn process_memory_inner(
    store: &MemoryStore,
    prompt: &str,
    response: &str,
    schedule_embedding: Option<&[f32]>,
) -> Vec<String> {
    let p_trimmed = prompt.trim();
    if p_trimmed.starts_with("[Internal:") {
        return Vec::new();
    }

    // ── Schedule note extraction (a feature, not memory extraction) ──────
    if let Some(note) = extract_schedule_note(prompt) {
        if let Err(e) = store.insert_memory_note("Schedule", &note, true, false, schedule_embedding)
        {
            eprintln!("[MEMORY] insert schedule note failed: {}", e);
        }
    }

    // ── Rolling conversation summary (for the notebook Summary tab) ──────
    if !response.contains("[Internal:") {
        if let Err(e) = store.replace_recent_conversation_summary(10) {
            eprintln!("[MEMORY] replace_recent_conversation_summary failed: {e}");
        }
    }

    // No new facts to embed — the conversation turn itself is embedded by
    // the caller. Return empty so the caller doesn't embed anything extra.
    Vec::new()
}

fn extract_schedule_note(prompt: &str) -> Option<String> {
    let cleaned = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    let lower = cleaned.to_lowercase();
    let scheduling_words = [
        "remind me",
        "wake me",
        "wake up",
        "set a reminder",
        "schedule",
        "don't let me forget",
        "dont let me forget",
    ];
    if !scheduling_words.iter().any(|w| lower.contains(w)) {
        return None;
    }

    let too_short = cleaned.chars().count() < 8;
    let too_long = cleaned.chars().count() > 240;
    if too_short || too_long {
        return None;
    }

    Some(format!("Schedule request: {}", cleaned))
}
