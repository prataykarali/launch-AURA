use include_dir::{include_dir, Dir};
use once_cell::sync::Lazy;
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};

/// All persona data is embedded at compile time so it works identically on Linux
/// desktop and Android (where the source tree is not available at runtime).
static PERSONA_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR/examples/persona_cases");

#[derive(Debug, Clone, Deserialize)]
pub struct PersonaCase {
    pub category: String,
    #[serde(rename = "type")]
    pub case_type: String,
    pub prompt: String,
    #[serde(default = "default_priority")]
    pub priority: i32,
    #[serde(default = "default_match_mode")]
    pub match_mode: String,
    pub expected_tone: String,
    pub memory_rule: String,
    pub reference_response: String,
}

fn default_priority() -> i32 {
    5
}

fn default_match_mode() -> String {
    "contains".to_string()
}

/// Canonical fast-path categories handled by `canonical_aura_reply`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CanonicalClass {
    Identity,
    Greeting,
    HowAreYou,
    Farewell,
}

/// In-memory repository for all persona examples, system prompt, and instructions.
pub struct PersonaBank {
    cases: Vec<PersonaCase>,
    by_category: HashMap<String, Vec<usize>>,
    fallback_by_type: HashMap<String, String>,
    system_prompt: String,
    memory_instruction: String,
    rotator: AtomicUsize,
}

impl PersonaBank {
    pub fn system_prompt(&self) -> &str {
        &self.system_prompt
    }

    pub fn memory_instruction(&self) -> &str {
        &self.memory_instruction
    }

    /// Classify a prompt into one of the canonical fast-path categories.
    /// Lower `priority` values win; identity always takes precedence over
    /// greeting/farewell/how-are-you when both match.
    pub fn classify_canonical(&self, prompt: &str, is_internal: bool) -> Option<CanonicalClass> {
        let prompt_lower = prompt.to_ascii_lowercase();
        let mut matched = None;
        let mut matched_priority = i32::MAX;

        for case in &self.cases {
            let class = match case.category.as_str() {
                "identity" => {
                    if is_internal {
                        continue;
                    }
                    CanonicalClass::Identity
                }
                "greeting" => CanonicalClass::Greeting,
                "how_are_you" => {
                    if is_internal {
                        continue;
                    }
                    CanonicalClass::HowAreYou
                }
                "farewell" => CanonicalClass::Farewell,
                _ => continue,
            };

            let max_len = match class {
                CanonicalClass::Identity => 48,
                CanonicalClass::Greeting => 16,
                CanonicalClass::HowAreYou => 32,
                CanonicalClass::Farewell => 24,
            };
            if prompt_lower.trim().len() >= max_len {
                continue;
            }

            if self.case_matches(case, &prompt_lower) && case.priority < matched_priority {
                matched = Some(class);
                matched_priority = case.priority;
            }
        }

        matched
    }

    fn case_matches(&self, case: &PersonaCase, prompt_lower: &str) -> bool {
        let needle = case.prompt.to_ascii_lowercase();
        let trimmed = prompt_lower.trim();
        match case.match_mode.as_str() {
            "exact" => trimmed == needle,
            "starts_with" => {
                trimmed == needle
                    || trimmed.starts_with(&format!("{needle} "))
                    || trimmed.starts_with(&format!("{needle}."))
                    || trimmed.starts_with(&format!("{needle}!"))
                    || trimmed.starts_with(&format!("{needle},"))
            }
            "contains" => prompt_lower.contains(&needle),
            "contains_all" => {
                // `prompt` field may contain comma-separated keywords.
                needle
                    .split(',')
                    .map(|s| s.trim())
                    .all(|k| !k.is_empty() && prompt_lower.contains(k))
            }
            _ => prompt_lower.contains(&needle),
        }
    }

    /// Return a rotating response from a canonical category.
    pub fn canonical_response(&self, class: CanonicalClass) -> Option<String> {
        let cat = match class {
            CanonicalClass::Identity => "identity",
            CanonicalClass::Greeting => "greeting",
            CanonicalClass::HowAreYou => "how_are_you",
            CanonicalClass::Farewell => "farewell",
        };
        let idxs = self.by_category.get(cat)?;
        if idxs.is_empty() {
            return None;
        }
        let i = self.rotator.fetch_add(1, Ordering::Relaxed) % idxs.len();
        Some(self.cases[idxs[i]].reference_response.clone())
    }

    pub fn fallback_response(&self, type_: &str) -> Option<&str> {
        self.fallback_by_type.get(type_).map(|s| s.as_str())
    }

    pub fn vision_fallback(&self, kind: &str) -> Option<&str> {
        self.fallback_by_type
            .get(&format!("vision_{kind}"))
            .map(|s| s.as_str())
    }

    pub fn all_cases(&self) -> &[PersonaCase] {
        &self.cases
    }
}

/// Global lazy-loaded persona bank.  Loaded once on first access; the embedded
/// files are already in the binary, so this is just parsing.
pub static PERSONA_BANK: Lazy<PersonaBank> = Lazy::new(|| {
    let mut cases: Vec<PersonaCase> = Vec::new();
    let mut system_prompt = String::new();
    let mut memory_instruction = String::new();

    for file in PERSONA_DIR.files() {
        let Some(content) = file.contents_utf8() else {
            continue;
        };
        let Some(name) = file.path().file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        match name {
            "system_prompt.txt" => system_prompt = content.to_string(),
            "memory_instruction.txt" => memory_instruction = content.to_string(),
            _ => {
                if file.path().extension().and_then(|e| e.to_str()) == Some("jsonl") {
                    for line in content.lines() {
                        let line = line.trim();
                        if line.is_empty() || line.starts_with("//") {
                            continue;
                        }
                        if let Ok(c) = serde_json::from_str::<PersonaCase>(line) {
                            cases.push(c);
                        }
                    }
                }
            }
        }
    }

    // Sort by priority so higher-priority (lower number) cases match first.
    cases.sort_by_key(|c| c.priority);

    let mut by_category: HashMap<String, Vec<usize>> = HashMap::new();
    let mut fallback_by_type: HashMap<String, String> = HashMap::new();
    for (i, c) in cases.iter().enumerate() {
        if c.category == "fallback" {
            fallback_by_type.insert(c.case_type.clone(), c.reference_response.clone());
        } else {
            by_category.entry(c.category.clone()).or_default().push(i);
        }
    }

    PersonaBank {
        cases,
        by_category,
        fallback_by_type,
        system_prompt,
        memory_instruction,
        rotator: AtomicUsize::new(0),
    }
});

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bank_loads_identity_cases() {
        let bank = &*PERSONA_BANK;
        assert!(
            bank.by_category.contains_key("identity"),
            "identity category should be loaded"
        );
        assert!(
            bank.system_prompt().contains("AURA"),
            "system prompt should be loaded"
        );
        assert!(
            bank.memory_instruction().contains("YOUR USER"),
            "memory instruction should be loaded"
        );
    }

    #[test]
    fn classify_identity_top_priority() {
        let bank = &*PERSONA_BANK;
        assert_eq!(
            bank.classify_canonical("who are you?", false),
            Some(CanonicalClass::Identity)
        );
        assert_eq!(
            bank.classify_canonical("aura", false),
            Some(CanonicalClass::Identity)
        );
        assert_eq!(
            bank.classify_canonical("tell me who i'm", false),
            None, // memory_recall, not identity
        );
    }

    #[test]
    fn classify_greeting_and_how_are_you() {
        let bank = &*PERSONA_BANK;
        assert_eq!(
            bank.classify_canonical("hi", false),
            Some(CanonicalClass::Greeting)
        );
        assert_eq!(
            bank.classify_canonical("how are you", false),
            Some(CanonicalClass::HowAreYou)
        );
        assert_eq!(
            bank.classify_canonical("bye", false),
            Some(CanonicalClass::Farewell)
        );
    }
}
