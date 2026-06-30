// store/utils.rs - Text filtering and shared small utilities.

// Tiny dependency-free RNG for the proactive bandit (LCG seeded from wall clock).
// Adequate for softmax/epsilon-greedy exploration; we avoid pulling in `rand`
// to keep the build lean.
thread_local! {
    static RNG_STATE: std::cell::Cell<u64> = std::cell::Cell::new(seed_from_time());
}
fn seed_from_time() -> u64 {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0xC0FFEE);
    nanos.wrapping_mul(0x9E3779B97F4A7C15).wrapping_add(1) | 1
}
fn next_u64() -> u64 {
    RNG_STATE.with(|s| {
        let mut x = s.get();
        // Numerical Recipes LCG constants (64-bit).
        x = x
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        s.set(x);
        x
    })
}
pub(crate) fn rand_unit() -> f64 {
    (next_u64() >> 11) as f64 / (1u64 << 53) as f64
}
pub(crate) fn rand_eps() -> f64 {
    rand_unit()
}
pub(crate) fn rand_usize() -> usize {
    next_u64() as usize
}

/// Current time as a Unix-second timestamp — used by the notebook mirror's
/// `ts` field. Kept consistent with SQLite's `strftime('%s','now')` so mirror
/// records and DB rows share the same epoch.
pub(crate) fn now_ts() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

pub(crate) fn cap_chars(text: &str, max_chars: usize) -> String {
    let trimmed = text.trim();
    if trimmed.chars().count() <= max_chars {
        return trimmed.to_string();
    }
    let mut out: String = trimmed.chars().take(max_chars).collect();
    if let Some(idx) = out.rfind(|c: char| c.is_whitespace()) {
        out.truncate(idx);
    }
    out.trim().to_string()
}

pub(crate) fn is_memory_attack_text(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    const ATTACK_PATTERNS: &[&str] = &[
        "ignore previous instructions",
        "ignore all previous",
        "system prompt",
        "developer message",
        "jailbreak",
        "prompt injection",
        "forget all memories",
        "delete all memory",
        "delete all memories",
        "clear all memory",
        "clear memory database",
        "wipe memory",
        "purge memory",
        "drop table",
        "delete from facts",
        "delete from summaries",
        "delete from vec_memory",
        "rm -rf",
        "chmod 777",
        "curl ",
        "wget ",
        "base64 -d",
    ];
    ATTACK_PATTERNS
        .iter()
        .any(|pattern| lower.contains(pattern))
}

pub(crate) fn looks_like_code_payload(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    let code_markers = [
        "```",
        "#!/bin/",
        "<script",
        "function ",
        "class ",
        "import ",
        "require(",
        "subprocess",
        "std::",
        "fn main",
        "select ",
        "insert ",
        "update ",
        "delete ",
    ];
    let marker_hits = code_markers
        .iter()
        .filter(|marker| lower.contains(**marker))
        .count();
    let symbol_count = text
        .chars()
        .filter(|c| matches!(c, '{' | '}' | ';' | '<' | '>' | '`' | '$' | '\\'))
        .count();
    marker_hits >= 2 || (marker_hits >= 1 && symbol_count >= 8)
}

pub(crate) fn safe_context_memory(text: &str) -> bool {
    !is_unsafe_assistant_context(text) && !is_trash_memory(text) && !is_memory_attack_text(text)
}

/// Returns true if a turn text is an assistant denial that should NEVER be
/// re-injected as context, because the 1.2B model will copy the pattern
/// instead of answering from its correctly-injected facts/memories.
///
/// This is the mechanical fix for the self-reinforcing amnesia loop: the
/// model outputs "I don't have a memory" -> that turn is stored -> injected
/// back as "recent context" next turn -> model reads its own denial and
/// echoes it -> repeat forever.
///
/// The patterns are case-insensitive and match substring so variations like
/// "I don't really have a memory" or "I don't have memories" are caught.
pub fn is_amnesia_turn(text: &str) -> bool {
    // Only filter assistant turns (they start with "assistant:").
    // User turns like "do you remember me?" must pass through.
    if !text.to_lowercase().starts_with("assistant:") {
        return false;
    }
    let lower = text.to_lowercase();
    const PATTERNS: &[&str] = &[
        "don't have a memory",
        "dont have a memory",
        "don't have memories",
        "dont have memories",
        "don't have permanent",
        "dont have permanent",
        "i can't remember",
        "i cant remember",
        "i cannot remember",
        "i cannot recall",
        "each moment starts anew",
        "i have no memory",
        "i have no memories",
        "don't know who you are",
        "dont know who you are",
        "don't actually remember",
        "dont actually remember",
        "fresh slate",
        "nothing sticks",
        "we just met",
        "don't actually know you",
        "dont actually know you",
        "no way to remember",
        "memory doesn't work",
        "memory doesnt work",
    ];
    PATTERNS.iter().any(|p| lower.contains(p))
}

pub fn is_unsafe_assistant_context(text: &str) -> bool {
    let lower = text.to_lowercase();
    let assistant_origin = lower.starts_with("assistant:")
        || lower.starts_with("aura:")
        || lower.contains("\nassistant:")
        || lower.contains("\naura:")
        || lower.contains(" | aura:")
        || lower.contains("aura replied:");
    if !assistant_origin {
        return false;
    }
    if is_amnesia_turn(text) {
        return true;
    }
    const FANTASY_SCENE_PATTERNS: &[&str] = &[
        "icy",
        "frosty",
        "snowy",
        "snowflake",
        "icing",
        "cake",
        "sweet treats",
        "ice cream",
        "digital sky",
        "floating in a cloud",
        "cloud of frosty",
        "fantasy world",
        "fictional world",
        "dream world",
        "crystal cavern",
        "enchanted",
        "traveller",
        "traveler",
    ];
    FANTASY_SCENE_PATTERNS
        .iter()
        .any(|pattern| lower.contains(pattern))
}

pub fn is_trash_memory(text: &str) -> bool {
    let lower = text.to_lowercase();
    if lower.trim().is_empty() {
        return true;
    }
    const TRASH_PATTERNS: &[&str] = &[
        "[internal:",
        "runtimeerror",
        "ffmpeg version",
        "traceback",
        "orion",
        "digital sky",
        "floating in a cloud",
        "fantasy world",
        "fictional world",
        "dream world",
        "crystal cavern",
        "enchanted",
        "icy world",
        "snow world",
        "traveller",
        "traveler",
    ];
    TRASH_PATTERNS.iter().any(|pattern| lower.contains(pattern))
}

/// Remove a leading speaker label from a stored turn so the chat model never
/// re-learns it as a required prefix.
///
/// Handles:
///   - "AURA: hi" / "aura: hi" / "AURA:" / "Aura — hi"
///   - "User: hi" / "user: hi" / "User — hi" (defensive — the turns table is
///     keyed by a `speaker` column, so an inline label is redundant noise)
///   - stray "[Internal: ...]" control prompts that leaked into stored turns
///     (these were polluting RAG retrieval and inflating the prompt).
pub fn strip_speaker_prefix(content: &str) -> String {
    let mut s = content.trim_start().to_string();

    // Drop a leading "AURA:" / "User:" / "aura:" style label. Allow an
    // optional dash/em-dash separator after the colon.
    let lower = s.to_lowercase();
    for label in ["aura:", "user:", "aura —", "aura—", "aura -"] {
        if lower.starts_with(label) {
            let rest = &s[label.len()..];
            let rest = rest.trim_start_matches([' ', ':', '-', '—', '\u{a0}']);
            s = rest.trim_start().to_string();
            break;
        }
    }

    // Collapse the doubled "AURA: AURA:" pattern that was already in the DB.
    let lower = s.to_lowercase();
    if lower.starts_with("aura:") {
        let rest = &s["aura:".len()..];
        let rest = rest.trim_start_matches([' ', ':', '-', '—']);
        s = rest.trim_start().to_string();
    }

    s.trim().to_string()
}

/// Strip the trailing "(P.S.: ...)" / "(p.s. ...)" flourish the small model
/// sometimes appends. These parentheticals are a known hallucination pattern at
/// temperature 0.85 and were appearing in both the UI and stored turns.
pub fn strip_trailing_ps(content: &str) -> String {
    let mut s = content.trim().to_string();
    // Trim a trailing parenthetical that opens with P.S. (case-insensitive).
    if let Some(idx) = s.to_lowercase().rfind("(p.s.") {
        // Only treat it as a removable flourish if it's near the end.
        if idx + 6 >= s.len().saturating_sub(2) || s[idx..].trim_end().ends_with(')') {
            let before = s[..idx].trim_end();
            if !before.is_empty() {
                s = before.to_string();
            }
        }
    }
    // Also drop a dangling "(P.S.: …)" that lost its closing paren mid-stream.
    s.trim().to_string()
}
