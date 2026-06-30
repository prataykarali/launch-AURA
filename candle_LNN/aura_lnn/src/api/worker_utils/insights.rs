use crate::memory::store::MemoryStore;

/// Derive durable *understandings* about the user from the current prompt and
/// persist them via `store.upsert_insight()` (which dedups on content and bumps
/// confidence/evidence_count on repeats).
///
/// These are deliberately cheap heuristics (no LLM call) — they look at surface
/// signals in the prompt that reliably indicate a recurring behaviour:
///   - question density   → "User is curious / asks many questions"
///   - exclamation energy → "User is enthusiastic / expressive"
///   - very short prompts → "User prefers concise interaction"
///   - self-disclosure    → "User shares personal details openly"
///
/// Each fires only when its signal clears a threshold, so the insight set stays
/// meaningful rather than recording every turn. `upsert_insight` is idempotent,
/// so re-deriving the same understanding just strengthens its confidence.
pub(crate) fn extract_insights(store: &MemoryStore, cleaned: &str) {
    let words: Vec<&str> = cleaned.split_whitespace().collect();
    if words.is_empty() {
        return;
    }

    // ── Question density ──────────────────────────────────────────────────
    // Count question marks and question openers. A prompt with 2+ questions, or
    // one starting with a question word, indicates a curious/interrogative
    // conversational style.
    let q_marks = cleaned.matches('?').count();
    let question_openers = [
        "what",
        "why",
        "how",
        "when",
        "where",
        "who",
        "which",
        "can you",
        "could you",
        "do you",
        "are you",
        "is it",
    ];
    let starts_with_q = question_openers.iter().any(|o| cleaned.starts_with(o));
    if q_marks >= 2 || (q_marks >= 1 && starts_with_q) {
        let _ = store.upsert_insight(
            "style",
            "User asks a lot of questions — prefers exploratory, curious conversation",
            0.1,
            "chat",
        );
    }

    // ── Expressiveness (exclamation / emphasis energy) ─────────────────────
    // A high ratio of '!' or ALL-CAPS words signals an enthusiastic tone.
    let excl = cleaned.matches('!').count();
    let caps_words = words
        .iter()
        .filter(|w| w.len() >= 3 && w.chars().all(|c| c.is_ascii_uppercase()))
        .count();
    if excl >= 2 || caps_words >= 2 {
        let _ = store.upsert_insight(
            "tone",
            "User is expressive and enthusiastic — uses exclamations and emphasis",
            0.1,
            "chat",
        );
    }

    // ── Concise-interaction preference ─────────────────────────────────────
    // Repeated very-short prompts ("hi", "ok", "yes", "thanks") indicate the
    // user likes brief exchanges. Fire on a short, non-question prompt.
    let is_short = words.len() <= 3 && q_marks == 0;
    if is_short {
        let _ = store.upsert_insight(
            "style",
            "User often sends short messages — likely prefers concise back-and-forth",
            0.05,
            "chat",
        );
    }

    // ── Openness to self-disclosure ────────────────────────────────────────
    // First-person self-statements ("i like", "i am", "my ...") indicate the
    // user willingly shares personal context — worth recording as a relational
    // pattern so AURA can reciprocate appropriately.
    let self_disclosure = [
        "i like ", "i love ", "i enjoy ", "i'm ", "im ", "i am ", "my ", "i feel ", "i work ",
        "i study ",
    ];
    let discloses = self_disclosure.iter().any(|a| cleaned.contains(a));
    if discloses {
        let _ = store.upsert_insight(
            "rapport",
            "User shares personal details and preferences openly — build on what they tell you",
            0.08,
            "chat",
        );
    }

    // ── MENTAL MODEL: Current Emotional State Heuristics ──────────────────
    let stress_words = [
        "stressed",
        "anxious",
        "worried",
        "nervous",
        "tired",
        "exhausted",
        "overwhelmed",
        "panic",
        "tension",
    ];
    if stress_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is currently feeling stressed, tired, or overwhelmed — respond with warmth, support, and empathy",
            0.15,
            "chat",
        );
    }

    let happy_words = [
        "happy",
        "excited",
        "glad",
        "awesome",
        "great",
        "wonderful",
        "cool",
        "super",
        "fantastic",
        "amazing",
    ];
    if happy_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is currently feeling positive or excited — match their energy and enthusiasm",
            0.15,
            "chat",
        );
    }

    let sad_words = [
        "sad",
        "depressed",
        "angry",
        "frustrated",
        "annoyed",
        "mad",
        "upset",
        "down",
        "disappointed",
        "hurt",
    ];
    if sad_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "mood",
            "User is currently feeling down, sad, or frustrated — be gentle, supportive, patient, and kind",
            0.15,
            "chat",
        );
    }

    // ── MENTAL MODEL: Temporal Patterns (Time of Day) ────────────────────
    if let Ok(local_time) = chrono::Local::now()
        .time()
        .format("%H")
        .to_string()
        .parse::<u32>()
    {
        if local_time >= 23 || local_time <= 4 {
            let _ = store.upsert_insight(
                "routine",
                "User is active late at night — they might be working late, a night owl, or have a late routine",
                0.05,
                "chat",
            );
        } else if (5..=9).contains(&local_time) {
            let _ = store.upsert_insight(
                "routine",
                "User is active early in the morning — they might have a structured morning routine",
                0.05,
                "chat",
            );
        }
    }

    // ── MENTAL MODEL: Interest Patterns ──────────────────────────────────
    let coding_words = [
        "coding",
        "programming",
        "rust",
        "python",
        "flutter",
        "dart",
        "compile",
        "bug",
        "git",
        "github",
        "code",
        "dev",
    ];
    if coding_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "interest",
            "User is highly interested in software development and coding",
            0.1,
            "chat",
        );
    }

    let academic_words = [
        "math",
        "physics",
        "study",
        "exam",
        "paper",
        "research",
        "mitacs",
        "university",
        "academic",
        "theory",
    ];
    if academic_words.iter().any(|w| cleaned.contains(w)) {
        let _ = store.upsert_insight(
            "interest",
            "User is focused on academic study or research work (including Mitacs related work)",
            0.1,
            "chat",
        );
    }
}
