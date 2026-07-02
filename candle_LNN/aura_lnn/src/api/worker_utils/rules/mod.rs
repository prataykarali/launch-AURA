// rules/mod.rs — Centralized memory extraction rules
//
// This module contains ALL the pattern-matching rules for extracting
// structured facts from user messages. Rules are organized into
// categories covering ~85% of real user memories.
//
// Categories:
//   identity   — name, age, gender, pronouns, occupation
//   family     — mom, dad, siblings, partner, friends
//   pets       — cats, dogs, other animals
//   preferences — likes, loves, hates, favorites
//   location   — city, country, origin
//   goals      — wants to learn, wants to do, aspirations
//   emotions   — current mood, feelings
//   events     — birthday, schedule, reminders

pub mod identity;
pub mod family;
pub mod pets;
pub mod preferences;
pub mod location;
pub mod goals;
pub mod emotions;
pub mod events;
pub mod edge_cases;

use crate::memory::store::MemoryStore;

/// Run ALL extraction rules on a cleaned (lowercased, whitespace-collapsed)
/// prompt and the original-case prompt. Returns a list of structured facts
/// like "User's name is X", "User loves Y", "User has a cat named Z".
///
/// Splits complex sentences into sub-clauses on conjunctions and commas so
/// multi-fact sentences like "I'm X, 24, living in Y with my cat Z".
/// Pixel" get each fact extracted individually.
/// Detect whether a cleaned (lowercased) prompt is a QUESTION about the user,
/// not a statement. Question prompts like "do i prefer coffee or tea",
/// "what is my name", "where do i live" must NOT be fed to the fact extractors
/// — the anchors ("i prefer ", "i live ") match inside the question and
/// produce garbage facts ("User prefers coffee or tea").
fn is_question_about_user(cleaned: &str) -> bool {
    let trimmed = cleaned.trim();
    if trimmed.is_empty() {
        return false;
    }
    // Explicit question mark is a strong signal.
    if trimmed.ends_with('?') {
        return true;
    }
    // Starts with a question word — covers the vast majority of recall queries.
    const QUESTION_STARTS: &[&str] = &[
        "do i ", "does i ", "did i ", "am i ", "is my ", "are my ", "was my ",
        "what is my ", "what's my ", "whats my ", "what are my ",
        "what was my ", "what did i ", "what do i ", "what have i ",
        "whats my ", "what is the ", "what is a ", "what is an ",
        "where do i ", "where did i ", "where is my ", "where's my ",
        "where am i ", "how old am i ", "how am i ", "how do i ", "how is my ",
        "who am i ", "who is my ", "who's my ",
        "why do i ", "why am i ", "why is my ",
        "can i ", "can you ", "could you ", "would you ", "should i ",
        "will i ", "have i ", "has my ",
        "tell me what ", "tell me about ", "list everything ", "list all ",
        "list what ", "show me what ",
        "what language", "what kind", "what type",
        "do i have", "do i like", "do i prefer", "do i need",
        "do i know", "do i want", "do i get",
    ];
    if QUESTION_STARTS.iter().any(|q| trimmed.starts_with(q)) {
        return true;
    }
    // Broader check: starts with a question word AND mentions the user
    // (" i ", " my ", " me ") early in the prompt.
    const Q_WORDS: &[&str] = &[
        "what ", "where ", "how ", "who ", "why ", "do ", "does ", "did ",
        "is ", "are ", "was ", "am ", "can ", "could ", "would ", "should ",
        "will ", "have ", "has ",
    ];
    let starts_with_q = Q_WORDS.iter().any(|q| trimmed.starts_with(q));
    if starts_with_q {
        let head: String = trimmed.chars().take(50).collect();
        if head.contains(" i ") || head.contains(" my ") || head.contains(" me ") {
            return true;
        }
    }
    false
}

pub fn extract_all_facts(cleaned: &str, original: &str) -> Vec<String> {
    // ── Guard: never extract facts from questions ──────────────────────
    // Questions like "do i prefer coffee or tea" contain anchors ("i prefer ")
    // that match inside the question and produce garbage facts. Skip ALL
    // extraction when the prompt is a question about the user.
    if is_question_about_user(cleaned) {
        return Vec::new();
    }

    let mut facts = Vec::new();

    // Always run on the full sentence first (catches patterns that span)
    facts.extend(run_all_extractors(cleaned, original));

    // Split into sub-clauses on conjunctions and commas, run on each.
    // This lets "I'm X, 24, living in Y" extract name + age + location
    // separately instead of only grabbing the first fact.
    let clauses = split_into_clauses(cleaned);
    for clause in &clauses {
        if clause.len() < 3 { continue; }
        facts.extend(run_all_extractors(clause, original));
    }

    // Dedup
    let mut seen = std::collections::HashSet::new();
    facts.retain(|f| seen.insert(f.to_lowercase()));
    facts
}

/// Split a cleaned sentence into sub-clauses on conjunctions and commas.
/// "i'm X, 24, living in Y with my cat Z" →
///   ["i'm X", "24", "living in Y", "with my cat Z"]
fn split_into_clauses(text: &str) -> Vec<String> {
    let mut clauses: Vec<String> = Vec::new();

    // Split on conjunctions first
    let conjoiners = [
        " and ", " but ", " so ", " because ", " while ", " though ",
        " however ", " although ", " yet ", " since ",
    ];
    let mut parts: Vec<String> = vec![text.to_string()];
    for conj in &conjoiners {
        let mut next = Vec::new();
        for p in &parts {
            for sub in p.split(conj) {
                next.push(sub.trim().to_string());
            }
        }
        parts = next;
    }

    // Further split each part on commas
    for p in &parts {
        for sub in p.split(',') {
            let trimmed = sub.trim();
            if !trimmed.is_empty() {
                clauses.push(trimmed.to_string());
            }
        }
    }

    // For clauses that look incomplete (no subject verb pattern),
    // try prepending the subject from the first clause.
    // e.g. "favorite coffee is pour over" + "board meeting every tuesday"
    // → second clause becomes "i have board meeting every tuesday"
    if clauses.len() >= 2 {
        let first = &clauses[0];
        let subject = extract_subject_verb(first);
        if let Some(prefix) = subject {
            for i in 1..clauses.len() {
                let clause = &clauses[i];
                // Only prepend if the clause doesn't already have a subject.
                if !has_subject_verb(clause) {
                    clauses[i] = format!("{} {}", prefix, clause);
                }
            }
        }
    }

    clauses
}

/// Extract the subject+verb prefix from a clause for inheritance.
/// "favorite coffee is pour over" → Some("my favorite")
/// "i live in vancouver" → Some("i live in")
fn extract_subject_verb(clause: &str) -> Option<String> {
    // "my favorite X is Y" → "my favorite"
    if clause.starts_with("my favorite ") || clause.starts_with("my favourite ") {
        return Some("my favorite".to_string());
    }
    // "i like X" → "i like"
    for verb in &["like ", "love ", "enjoy ", "prefer ", "hate "] {
        if clause.starts_with(verb) {
            return Some(format!("i {}", verb.trim_end()));
        }
    }
    None
}

/// Check if a clause already has a subject+verb pattern.
fn has_subject_verb(clause: &str) -> bool {
    let starters = [
        "i ", "my ", "user ", "we ", "he ", "she ", "they ",
        "the ", "a ", "an ", "this ", "that ",
    ];
    starters.iter().any(|s| clause.starts_with(s))
}

fn run_all_extractors(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();
    facts.extend(identity::extract(cleaned, original));
    facts.extend(family::extract(cleaned, original));
    facts.extend(pets::extract(cleaned, original));
    facts.extend(preferences::extract(cleaned, original));
    facts.extend(location::extract(cleaned, original));
    facts.extend(goals::extract(cleaned, original));
    facts.extend(emotions::extract(cleaned, original));
    facts.extend(events::extract(cleaned, original));
    facts.extend(edge_cases::extract(cleaned, original));
    facts
}

/// Derive behavioral insights from the prompt (mood, style, interests)
pub fn extract_all_insights(store: &MemoryStore, cleaned: &str) {
    emotions::extract_insights(store, cleaned);
}

/// Check if a fact string matches our allowed prefixes
pub fn is_valid_fact(fact: &str) -> bool {
    let lower = fact.trim().to_ascii_lowercase();
    if lower.is_empty() || fact.chars().count() > 220 { return false; }
    if lower.starts_with("[internal:") { return false; }
    if lower.contains("vision:") || lower.contains("objects=[") { return false; }
    if lower.contains("screen_visible") || lower.contains("detection") { return false; }

    // Quantified pets: "User has 2 cats", "User has three dogs"
    if lower.starts_with("user has ") {
        let rest = &lower[9..];
        if rest.chars().next().map(|c| c.is_ascii_digit()).unwrap_or(false) {
            return true;
        }
    }

    const VALID_PREFIXES: &[&str] = &[
        "user's name is ", "user's age is ",
        "user's favorite ", "user's favourite ",
        "user's birthday is ",
        "user's pronouns are ",
        "user's mood is ",
        "user's hobby is ",
        "user lives in ", "user is based in ", "user moved to ", "user is from ",
        "user likes ", "user loves ", "user enjoys ", "user prefers ", "user hates ",
        "user dislikes ", "user is really into ", "user is into ",
        "user listens to ", "user is interested in ", "user is a fan of ",
        "user is a ", "user is an ", "user is the ",
        "user is non-binary", "user is transgender",
        "user studies ", "user studies at ", "user works as ", "user works at ",
        "user teaches ", "user runs ",
        "user has a ", "user has an ",
        "user has mom named ", "user has mum named ",
        "user has dad named ", "user has mother named ", "user has father named ",
        "user has sister named ", "user has brother named ",
        "user has friend named ", "user has best friend named ",
        "user has boyfriend named ", "user has girlfriend named ",
        "user has partner named ", "user has spouse named ",
        "user has son named ", "user has daughter named ",
        "user has child named ", "user has kid named ",
        "user has grandma named ", "user has grandpa named ",
        "user has grandmother named ", "user has grandfather named ",
        "user has aunt named ", "user has uncle named ",
        "user has cousin named ", "user has niece named ", "user has nephew named ",
        "user has roommate named ",
        "user wants to learn ", "user wants to ",
        "user is learning ", "user is reading ",
        "user feels ", "user is feeling ",
        "user likes playing ", "user likes watching ", "user likes reading ",
        // Edge case facts
        "user's favorite professor is ", "user's favorite teacher is ",
        "user has boss named ",
        "user is allergic to ", "user has asthma", "user has diabetes",
        "user is lactose intolerant", "user is vegan", "user is vegetarian",
        // Event facts
        "user has an exam ", "user has a deadline ", "user has a thesis deadline ",
        "user has an interview ", "user has a job interview ",
        "user has a presentation ", "user has a wedding on ",
        "user has a flight on ", "user has a flight to ",
        "user has an appointment at ", "user has an appointment on ",
        "user has a dentist appointment ", "user has a doctor appointment ",
        "user has a meeting at ", "user has a meeting on ", "user has a meeting ",
    ];

    VALID_PREFIXES.iter().any(|p| lower.starts_with(p))
}
