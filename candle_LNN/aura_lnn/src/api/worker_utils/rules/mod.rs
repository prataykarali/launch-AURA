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

pub mod edge_cases;
pub mod emotions;
pub mod events;
pub mod family;
pub mod goals;
pub mod identity;
pub mod location;
pub mod pets;
pub mod preferences;

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
        "do i ",
        "does i ",
        "did i ",
        "am i ",
        "is my ",
        "are my ",
        "was my ",
        "what is my ",
        "what's my ",
        "whats my ",
        "what are my ",
        "what was my ",
        "what did i ",
        "what do i ",
        "what have i ",
        "whats my ",
        "what is the ",
        "what is a ",
        "what is an ",
        "where do i ",
        "where did i ",
        "where is my ",
        "where's my ",
        "where am i ",
        "how old am i ",
        "how am i ",
        "how do i ",
        "how is my ",
        "who am i ",
        "who is my ",
        "who's my ",
        "why do i ",
        "why am i ",
        "why is my ",
        "can i ",
        "can you ",
        "could you ",
        "would you ",
        "should i ",
        "will i ",
        "have i ",
        "has my ",
        "tell me what ",
        "tell me about ",
        "list everything ",
        "list all ",
        "list what ",
        "show me what ",
        "what language",
        "what kind",
        "what type",
        "do i have",
        "do i like",
        "do i prefer",
        "do i need",
        "do i know",
        "do i want",
        "do i get",
    ];
    if QUESTION_STARTS.iter().any(|q| trimmed.starts_with(q)) {
        return true;
    }
    // Broader check: starts with a question word AND mentions the user
    // (" i ", " my ", " me ") early in the prompt.
    const Q_WORDS: &[&str] = &[
        "what ", "where ", "how ", "who ", "why ", "do ", "does ", "did ", "is ", "are ", "was ",
        "am ", "can ", "could ", "would ", "should ", "will ", "have ", "has ",
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
        if clause.len() < 3 {
            continue;
        }
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
        " and ",
        " but ",
        " so ",
        " because ",
        " while ",
        " though ",
        " however ",
        " although ",
        " yet ",
        " since ",
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
        "i ", "my ", "user ", "we ", "he ", "she ", "they ", "the ", "a ", "an ", "this ", "that ",
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
    if lower.is_empty() || fact.chars().count() > 220 {
        return false;
    }
    if lower.starts_with("[internal:") {
        return false;
    }
    if lower.contains("vision:") || lower.contains("objects=[") {
        return false;
    }
    if lower.contains("screen_visible") || lower.contains("detection") {
        return false;
    }

    // Quantified pets: "User has 2 cats", "User has three dogs"
    if lower.starts_with("user has ") {
        let rest = &lower[9..];
        if rest
            .chars()
            .next()
            .map(|c| c.is_ascii_digit())
            .unwrap_or(false)
        {
            return true;
        }
    }

    const VALID_PREFIXES: &[&str] = &[
        "user's name is ",
        "user's age is ",
        "user's favorite ",
        "user's favourite ",
        "user's birthday is ",
        "user's pronouns are ",
        "user's mood is ",
        "user's hobby is ",
        "user lives in ",
        "user is based in ",
        "user moved to ",
        "user is from ",
        "user likes ",
        "user loves ",
        "user enjoys ",
        "user prefers ",
        "user hates ",
        "user dislikes ",
        "user is really into ",
        "user is into ",
        "user listens to ",
        "user is interested in ",
        "user is a fan of ",
        "user is a ",
        "user is an ",
        "user is the ",
        "user is non-binary",
        "user is transgender",
        "user studies ",
        "user studies at ",
        "user works as ",
        "user works at ",
        "user teaches ",
        "user runs ",
        "user has a ",
        "user has an ",
        "user has mom named ",
        "user has mum named ",
        "user has dad named ",
        "user has mother named ",
        "user has father named ",
        "user has sister named ",
        "user has brother named ",
        "user has friend named ",
        "user has best friend named ",
        "user has boyfriend named ",
        "user has girlfriend named ",
        "user has partner named ",
        "user has spouse named ",
        "user has son named ",
        "user has daughter named ",
        "user has child named ",
        "user has kid named ",
        "user has grandma named ",
        "user has grandpa named ",
        "user has grandmother named ",
        "user has grandfather named ",
        "user has aunt named ",
        "user has uncle named ",
        "user has cousin named ",
        "user has niece named ",
        "user has nephew named ",
        "user has roommate named ",
        "user wants to learn ",
        "user wants to ",
        "user is learning ",
        "user is reading ",
        "user feels ",
        "user is feeling ",
        "user likes playing ",
        "user likes watching ",
        "user likes reading ",
        // Edge case facts
        "user's favorite professor is ",
        "user's favorite teacher is ",
        "user has boss named ",
        "user is allergic to ",
        "user has asthma",
        "user has diabetes",
        "user is lactose intolerant",
        "user is vegan",
        "user is vegetarian",
        // Event facts
        "user has an exam ",
        "user has a deadline ",
        "user has a thesis deadline ",
        "user has an interview ",
        "user has a job interview ",
        "user has a presentation ",
        "user has a wedding on ",
        "user has a flight on ",
        "user has a flight to ",
        "user has an appointment at ",
        "user has an appointment on ",
        "user has a dentist appointment ",
        "user has a doctor appointment ",
        "user has a meeting at ",
        "user has a meeting on ",
        "user has a meeting ",
    ];

    VALID_PREFIXES.iter().any(|p| lower.starts_with(p))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AkfTriple {
    pub subject_kind: String,
    pub subject_name: String,
    pub rel: String,
    pub object_kind: String,
    pub object_name: String,
    pub summary: String,
}

/// Parse a natural fact string into an Atomic Knowledge Fact (AKF) graph node + edge triple.
pub fn parse_fact_to_akf(fact: &str) -> Option<AkfTriple> {
    let orig = fact.trim();
    let lower = orig.to_lowercase();
    if lower.is_empty() {
        return None;
    }

    if let Some(rest) = lower.strip_prefix("user's name is ") {
        let offset = orig.len() - rest.len();
        let name = orig[offset..].trim();
        if !name.is_empty() {
            return Some(AkfTriple {
                subject_kind: "person".to_string(),
                subject_name: "user".to_string(),
                rel: "NAME_IS".to_string(),
                object_kind: "person".to_string(),
                object_name: name.to_string(),
                summary: orig.to_string(),
            });
        }
    }

    if let Some(rest) = lower.strip_prefix("user's age is ") {
        let offset = orig.len() - rest.len();
        let age = orig[offset..].trim();
        if !age.is_empty() {
            return Some(AkfTriple {
                subject_kind: "person".to_string(),
                subject_name: "user".to_string(),
                rel: "AGE_IS".to_string(),
                object_kind: "pref".to_string(),
                object_name: age.to_string(),
                summary: orig.to_string(),
            });
        }
    }

    // Pets: "user has a cat named mochi", "user has a dog named max", "user has cat named mochi"
    for pet_type in &["cat", "dog", "bird", "fish", "hamster", "rabbit", "pet"] {
        let prefix_a = format!("user has a {} named ", pet_type);
        let prefix_an = format!("user has an {} named ", pet_type);
        let prefix_plain = format!("user has {} named ", pet_type);
        let matched_len = if lower.starts_with(&prefix_a) {
            Some(prefix_a.len())
        } else if lower.starts_with(&prefix_an) {
            Some(prefix_an.len())
        } else if lower.starts_with(&prefix_plain) {
            Some(prefix_plain.len())
        } else {
            None
        };

        if let Some(len) = matched_len {
            if len <= orig.len() {
                let pet_name = orig[len..].trim();
                if !pet_name.is_empty() {
                    return Some(AkfTriple {
                        subject_kind: "person".to_string(),
                        subject_name: "user".to_string(),
                        rel: "HAS_PET".to_string(),
                        object_kind: "pet".to_string(),
                        object_name: pet_name.to_string(),
                        summary: format!("{} named {}", pet_type, pet_name),
                    });
                }
            }
        }
    }

    // Family: "user has mom named X", "user has sister named Y"
    for rel_type in &[
        "mom", "mum", "dad", "mother", "father", "sister", "brother",
        "friend", "best friend", "boyfriend", "girlfriend", "partner",
        "spouse", "son", "daughter", "child", "kid", "roommate", "boss",
    ] {
        let prefix = format!("user has {} named ", rel_type);
        if lower.starts_with(&prefix) && prefix.len() <= orig.len() {
            let name = orig[prefix.len()..].trim();
            if !name.is_empty() {
                return Some(AkfTriple {
                    subject_kind: "person".to_string(),
                    subject_name: "user".to_string(),
                    rel: format!("HAS_{}", rel_type.replace(' ', "_").to_uppercase()),
                    object_kind: "person".to_string(),
                    object_name: name.to_string(),
                    summary: format!("{} named {}", rel_type, name),
                });
            }
        }
    }

    // Location: "user lives in Vancouver", "user is from Toronto", "user is based in Seattle"
    for loc_prefix in &["user lives in ", "user is based in ", "user is from ", "user moved to "] {
        if lower.starts_with(loc_prefix) && loc_prefix.len() <= orig.len() {
            let loc = orig[loc_prefix.len()..].trim();
            if !loc.is_empty() {
                return Some(AkfTriple {
                    subject_kind: "person".to_string(),
                    subject_name: "user".to_string(),
                    rel: "LIVES_IN".to_string(),
                    object_kind: "place".to_string(),
                    object_name: loc.to_string(),
                    summary: format!("lives in {}", loc),
                });
            }
        }
    }

    // Preferences: "user likes pizza", "user loves coding", "user prefers tea"
    for pref_prefix in &[
        ("user's favorite ", "FAVORITE"),
        ("user's favourite ", "FAVORITE"),
        ("user likes ", "LIKES"),
        ("user loves ", "LOVES"),
        ("user enjoys ", "ENJOYS"),
        ("user prefers ", "PREFERS"),
        ("user hates ", "HATES"),
        ("user dislikes ", "DISLIKES"),
        ("user is really into ", "INTO"),
        ("user is into ", "INTO"),
        ("user is a fan of ", "FAN_OF"),
    ] {
        if lower.starts_with(pref_prefix.0) && pref_prefix.0.len() <= orig.len() {
            let item = orig[pref_prefix.0.len()..].trim();
            if !item.is_empty() {
                return Some(AkfTriple {
                    subject_kind: "person".to_string(),
                    subject_name: "user".to_string(),
                    rel: pref_prefix.1.to_string(),
                    object_kind: "pref".to_string(),
                    object_name: item.to_string(),
                    summary: orig.to_string(),
                });
            }
        }
    }

    // Academics/Course/Work: "user studies CS", "user works as engineer"
    for study_prefix in &[
        ("user studies ", "STUDIES", "course"),
        ("user studies at ", "STUDIES_AT", "place"),
        ("user works as ", "WORKS_AS", "pref"),
        ("user works at ", "WORKS_AT", "place"),
        ("user wants to learn ", "WANTS_LEARN", "goal"),
        ("user wants to ", "WANTS_TO", "goal"),
        ("user is learning ", "LEARNING", "course"),
    ] {
        if lower.starts_with(study_prefix.0) && study_prefix.0.len() <= orig.len() {
            let item = orig[study_prefix.0.len()..].trim();
            if !item.is_empty() {
                return Some(AkfTriple {
                    subject_kind: "person".to_string(),
                    subject_name: "user".to_string(),
                    rel: study_prefix.1.to_string(),
                    object_kind: study_prefix.2.to_string(),
                    object_name: item.to_string(),
                    summary: orig.to_string(),
                });
            }
        }
    }

    // Default fallback for any valid fact
    Some(AkfTriple {
        subject_kind: "person".to_string(),
        subject_name: "user".to_string(),
        rel: "FACT".to_string(),
        object_kind: "pref".to_string(),
        object_name: orig.to_string(),
        summary: orig.to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_fact_to_akf() {
        let pet_fact = "User has a cat named Mochi";
        let akf = parse_fact_to_akf(pet_fact).unwrap();
        assert_eq!(akf.subject_name, "user");
        assert_eq!(akf.rel, "HAS_PET");
        assert_eq!(akf.object_name, "Mochi");
        assert_eq!(akf.object_kind, "pet");

        let name_fact = "User's name is Pratay";
        let akf_name = parse_fact_to_akf(name_fact).unwrap();
        assert_eq!(akf_name.rel, "NAME_IS");
        assert_eq!(akf_name.object_name, "Pratay");
        assert_eq!(akf_name.object_kind, "person");

        let loc_fact = "User lives in Vancouver";
        let akf_loc = parse_fact_to_akf(loc_fact).unwrap();
        assert_eq!(akf_loc.rel, "LIVES_IN");
        assert_eq!(akf_loc.object_name, "Vancouver");
        assert_eq!(akf_loc.object_kind, "place");
    }
}


