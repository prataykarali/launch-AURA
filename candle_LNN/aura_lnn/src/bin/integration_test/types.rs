use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
pub struct TestResult {
    pub id: usize,
    pub suite: String,
    pub category: String,
    pub difficulty: String,
    pub passed: bool,
    pub description: String,
    pub detail: String,
    pub duration_ms: u64,
}

use aura_lnn::vision::events::VisionDetection;

pub fn det(label: &str, confidence: f32) -> VisionDetection {
    VisionDetection { label: label.to_string(), confidence, bbox: None }
}

pub fn schedule_detect(prompt: &str) -> bool {
    let cleaned = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    let lower = cleaned.to_lowercase();
    let words = ["remind me","wake me","wake up","set a reminder","schedule","don't let me forget","dont let me forget"];
    if !words.iter().any(|w| lower.contains(w)) { return false; }
    (8..=240).contains(&cleaned.chars().count())
}

pub fn is_vision_query(prompt_lower: &str) -> bool {
    ["see","look","watch","camera","surroundings","environment","room","desk","wearing","carrying","wave","waving","hand","gesture","action","doing"]
        .iter().any(|w| prompt_lower.contains(w))
}
