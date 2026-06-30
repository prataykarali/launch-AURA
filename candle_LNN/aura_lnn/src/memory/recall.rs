use once_cell::sync::Lazy;
use std::collections::{HashMap, HashSet};
use std::sync::Mutex;

fn memory_topic_key(layer: &str, text: &str) -> String {
    let mut cleaned = text
        .trim()
        .trim_start_matches("Summary:")
        .trim_start_matches("Understanding")
        .trim_start_matches("Possible")
        .trim()
        .to_ascii_lowercase();
    cleaned = cleaned
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c.is_whitespace() {
                c
            } else {
                ' '
            }
        })
        .collect::<String>()
        .split_whitespace()
        .take(24)
        .collect::<Vec<_>>()
        .join(" ");
    format!("{layer}:{cleaned}")
}

/// Consecutive-turn guard for all memory items (facts, RAG, etc.). Allows a
/// memory to be injected at most twice in a row; after that it is dropped from
/// the slate so the next relevant memory can surface when the chat drifts.
static CONSECUTIVE_MEMORY_GUARD: Lazy<Mutex<ConsecutiveMemoryGuard>> =
    Lazy::new(|| Mutex::new(ConsecutiveMemoryGuard::default()));

#[derive(Default)]
struct ConsecutiveMemoryGuard {
    prev_turn: HashSet<String>,
    current_turn: HashSet<String>,
    consecutive: HashMap<String, usize>,
}

impl ConsecutiveMemoryGuard {
    const MAX_CONSECUTIVE: usize = 2;

    fn begin_turn(&mut self) {
        let mut new_consecutive = HashMap::new();
        for key in &self.current_turn {
            let count = if self.prev_turn.contains(key) {
                self.consecutive.get(key).copied().unwrap_or(1) + 1
            } else {
                1
            };
            new_consecutive.insert(key.clone(), count);
        }
        self.prev_turn = std::mem::take(&mut self.current_turn);
        self.consecutive = new_consecutive;
    }

    fn try_use(&mut self, text: &str) -> bool {
        let key = memory_topic_key("memory", text);
        if key.is_empty() {
            return false;
        }
        if self.current_turn.contains(&key) {
            return false;
        }
        if self.consecutive.get(&key).copied().unwrap_or(0) >= Self::MAX_CONSECUTIVE {
            return false;
        }
        self.current_turn.insert(key);
        true
    }
}

pub(crate) fn begin_memory_turn() {
    CONSECUTIVE_MEMORY_GUARD
        .lock()
        .map(|mut guard| guard.begin_turn())
        .ok();
}

pub(crate) fn should_inject_memory_item(text: &str) -> bool {
    CONSECUTIVE_MEMORY_GUARD
        .lock()
        .map(|mut guard| guard.try_use(text))
        .unwrap_or(true)
}

pub(crate) fn extract_schedule_note_hint(prompt: &str) -> Option<String> {
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
    Some(format!("Schedule request: {cleaned}"))
}

#[cfg(test)]
mod tests {
    use super::ConsecutiveMemoryGuard;

    #[test]
    fn consecutive_memory_guard_allows_two_then_suppresses() {
        let mut guard = ConsecutiveMemoryGuard::default();
        let fact = "User's name is Pratay";

        guard.begin_turn();
        assert!(guard.try_use(fact)); // first use
        guard.begin_turn();
        assert!(guard.try_use(fact)); // second consecutive use
        guard.begin_turn();
        assert!(!guard.try_use(fact)); // third consecutive use suppressed
        guard.begin_turn();
        // After a drift turn (nothing used), the memory returns to the slate.
        assert!(guard.try_use(fact));
    }

    #[test]
    fn consecutive_memory_guard_deduplicates_within_turn() {
        let mut guard = ConsecutiveMemoryGuard::default();
        let fact = "User likes pizza";

        guard.begin_turn();
        assert!(guard.try_use(fact));
        assert!(!guard.try_use(fact)); // same memory in the same turn is skipped
        assert!(guard.try_use("User's name is Pratay")); // a different memory is allowed
    }
}
