use crate::memory::store::MemoryStore;

use super::rules;

/// Post-turn memory processing.
///
/// Uses the centralized rules engine to extract structured facts from
/// the user's prompt, stores them in the `facts` table, derives behavioral
/// insights, and maintains a rolling conversation summary. Returns clean
/// fact strings for the caller to embed into vec_memory.
pub(crate) fn process_memory_inner(
    store: &MemoryStore,
    prompt: &str,
    response: &str,
    schedule_embedding: Option<&[f32]>,
) -> Vec<String> {
    let p_trimmed = prompt.trim();
    if p_trimmed.starts_with("[Internal:")
        || p_trimmed.starts_with("[MEMORY:")
        || p_trimmed.starts_with("[KNOW:")
    {
        return Vec::new();
    }

    let cleaned: String = p_trimmed
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase();

    // ── Correction handling ───────────────────────────────────────────
    // If the user corrects themselves ("just kidding, it's X", "actually Y",
    // "wait no, Z"), use ONLY the part after the correction phrase so we
    // don't extract the old/wrong fact. ALSO delete the old conflicting facts.
    let (cleaned, p_trimmed, is_correction) = apply_correction(&cleaned, p_trimmed);

    // If correction detected, delete old facts that conflict with the new ones
    if is_correction {
        eprintln!("[MEMORY] Correction detected — deleting old conflicting facts");
        delete_conflicting_facts(store, &cleaned);
    }

    // Schedule note extraction
    // Store as NON-pinned so schedule reminders don't leak into regular chat
    // context. The proactive scheduler reads these via get_proactive_context()
    // which queries memory_notes directly — pinning is unnecessary and causes
    // the reminder text to bleed into normal chat responses (Issue #18).
    if let Some(note) = extract_schedule_note(prompt) {
        if let Err(e) =
            store.insert_memory_note("Schedule", &note, false, false, schedule_embedding)
        {
            eprintln!("[MEMORY] insert schedule note failed: {}", e);
        }
    }

    // ── Structured fact extraction via rules engine ──────────────────
    let new_facts = rules::extract_all_facts(&cleaned, p_trimmed);
    for fact in &new_facts {
        if rules::is_valid_fact(fact) {
            if let Err(e) = store.insert_fact(fact) {
                eprintln!("[MEMORY] insert fact failed: {}", e);
            } else {
                #[cfg(debug_assertions)]
                eprintln!("[MEMORY] Extracted fact: {}", fact);
            }

            // Dual-write: Archipelago Graph RAG (nodes + directed edges)
            if let Some(akf) = rules::parse_fact_to_akf(fact) {
                let user_res = store.upsert_node(
                    &akf.subject_name,
                    &akf.subject_kind,
                    Some("User profile anchor"),
                    None,
                    "rule",
                    None,
                );
                let obj_res = store.upsert_node(
                    &akf.object_name,
                    &akf.object_kind,
                    Some(&akf.summary),
                    None,
                    "rule",
                    None,
                );
                if let (Ok(user_id), Ok(obj_id)) = (user_res, obj_res) {
                    if let Err(e) = store.insert_edge(user_id, &akf.rel, obj_id) {
                        eprintln!("[MEMORY] insert graph edge failed: {}", e);
                    }
                }
            }
        }
    }

    // ── Behavioral insights ──────────────────────────────────────────
    rules::extract_all_insights(store, &cleaned);

    // ── Rolling conversation summary ─────────────────────────────────
    if !response.contains("[Internal:") {
        if let Err(e) = store.replace_recent_conversation_summary(10) {
            eprintln!("[MEMORY] summary failed: {e}");
        }
    }

    // ── Periodic maintenance: prevent unbounded table growth ────────
    // Every 20 turns, fold old turns into summaries and trim vec_memory /
    // proactive_log so they don't grow without bound during normal operation.
    // Without this, long sessions (like the 3.5hr Sam test) accumulate
    // hundreds of MB of stale embeddings and turns that are never reclaimed
    // until a critical memory-pressure event.
    if let Ok(count) = store.turn_count() {
        if count % 20 == 0 {
            if let Err(e) = store.periodic_maintenance() {
                eprintln!("[MEMORY] periodic maintenance failed: {e}");
            } else {
                eprintln!("[MEMORY] periodic maintenance completed (turn_count={count})");
            }
        }
    }

    new_facts
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
    if !(8..=240).contains(&cleaned.chars().count()) {
        return None;
    }
    Some(format!("Schedule request: {}", cleaned))
}

/// Detect self-correction phrases and return only the part AFTER the correction.
/// "my name is X. just kidding, it's Y" → "it's Y"
/// "i hate coffee. wait no, i love coffee" → "i love coffee"
/// "i'm 24. actually i just turned 25" → "i just turned 25"
fn apply_correction<'a>(cleaned: &str, original: &'a str) -> (String, &'a str, bool) {
    let lower = cleaned;
    let correction_phrases = [
        "just kidding",
        "wait no",
        "wait, no",
        "actually",
        "no wait",
        "sorry, i meant",
        "sorry i meant",
        "i mean",
        "scratch that",
        "never mind",
        "nevermind",
        "correction:",
    ];

    for phrase in &correction_phrases {
        if let Some(pos) = lower.find(phrase) {
            let after = &lower[pos + phrase.len()..]
                .trim_start_matches(|c: char| c == ',' || c == ' ' || c == '.');
            if after.len() >= 3 {
                #[cfg(debug_assertions)]
                eprintln!(
                    "[MEMORY] Correction detected: '{}' → using only '{}'",
                    phrase, after
                );
                let orig_lower = original.to_lowercase();
                if let Some(orig_pos) = orig_lower.find(phrase) {
                    let orig_after = &original[orig_pos + phrase.len()..]
                        .trim_start_matches(|c: char| c == ',' || c == ' ' || c == '.');
                    return (after.to_string(), orig_after, true);
                }
                return (after.to_string(), original, true);
            }
        }
    }
    (cleaned.to_string(), original, false)
}

/// Delete old facts that conflict with the corrected text.
/// e.g. if corrected text says "my cat's name is Patches", delete
/// "User has a cat named Patchwork" from the facts table.
fn delete_conflicting_facts(store: &MemoryStore, corrected: &str) {
    let lower = corrected.to_lowercase();
    // Name correction
    if lower.contains("name is") || lower.contains("name's") || lower.contains("called") {
        let _ = store.delete_name_facts();
        eprintln!("[MEMORY] Deleted old name facts due to correction");
    }
    // Cat/pet correction — delete old pet facts
    if lower.contains("cat") || lower.contains("dog") || lower.contains("pet") {
        let _ = store.delete_facts_matching_pattern("User has a cat named %");
        let _ = store.delete_facts_matching_pattern("User has a dog named %");
        let _ = store.delete_facts_matching_pattern("User has % cats");
        let _ = store.delete_facts_matching_pattern("User has % dogs");
        eprintln!("[MEMORY] Deleted old pet facts due to correction");
    }
    // Location correction
    if lower.contains("live in") || lower.contains("live at") || lower.contains("moved to") {
        let _ = store.delete_facts_matching_pattern("User lives in %");
        let _ = store.delete_facts_matching_pattern("User is from %");
        eprintln!("[MEMORY] Deleted old location facts due to correction");
    }
    // Age correction
    if lower.contains("years old") || lower.contains("age is") {
        let _ = store.delete_facts_matching_pattern("User's age is %");
        eprintln!("[MEMORY] Deleted old age facts due to correction");
    }
}
