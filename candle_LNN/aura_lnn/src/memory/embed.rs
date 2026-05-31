use fastembed::{EmbeddingModel, InitOptions, TextEmbedding};
use anyhow::Result;

pub struct Embedder {
    model: TextEmbedding,
}

// Canonical "intents" we care about — embed once, reuse for comparison
const FACT_PATTERNS: &[(&str, &str)] = &[
    ("user_name",     "my name is"),
    ("user_name",     "call me"),
    ("user_name",     "i am called"),
    ("user_age",      "i am years old"),
    ("user_age",      "my age is"),
    ("user_likes",    "i love i like my favourite"),
    ("user_dislikes", "i hate i don't like i dislike"),
    ("user_feeling",  "i feel i am feeling i am sad happy anxious tired"),
    ("user_location", "i live in i am from my city my country"),
];

// Cosine similarity between two vectors
fn cosine(a: &[f32], b: &[f32]) -> f32 {
    let dot: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    let na: f32  = a.iter().map(|x| x * x).sum::<f32>().sqrt();
    let nb: f32  = b.iter().map(|x| x * x).sum::<f32>().sqrt();
    if na == 0.0 || nb == 0.0 { 0.0 } else { dot / (na * nb) }
}

impl Embedder {
    pub fn new() -> Result<Self> {
        let model = TextEmbedding::try_new(
            InitOptions::new(EmbeddingModel::SnowflakeArcticEmbedS)
                .with_show_download_progress(false),
        )?;
        Ok(Self { model })
    }

    pub fn embed(&mut self, text: &str) -> Result<Vec<f32>> {
        let results = self.model.embed(vec![text], None)?;
        Ok(results.into_iter().next().expect("no embedding returned"))
    }

    pub fn to_bytes(v: &[f32]) -> &[u8] {
        unsafe {
            std::slice::from_raw_parts(v.as_ptr() as *const u8, v.len() * 4)
        }
    }

    /// Semantically detect if a user message is declaring a personal fact.
    /// Returns (fact_key, extracted_value) if confident enough.
    /// Threshold 0.72 — high enough to avoid false positives on 750MB model.
    pub fn detect_fact(&mut self, user_msg: &str) -> Option<(String, String)> {
        let msg_lower = user_msg.to_lowercase();
        let msg_vec = self.embed(&msg_lower).ok()?;

        let mut best_key: Option<&str> = None;
        let mut best_score = 0.0f32;

        for (key, pattern) in FACT_PATTERNS {
            if let Ok(pat_vec) = self.embed(pattern) {
                let score = cosine(&msg_vec, &pat_vec);
                if score > best_score {
                    best_score = score;
                    best_key = Some(key);
                }
            }
        }

        // Only act if similarity is high enough
        if best_score < 0.72 {
            return None;
        }

        let key = best_key?;

        // Extract the value based on key type
        let value = match key {
            "user_name" => extract_name(&msg_lower)?,
            "user_age"  => extract_age(&msg_lower)?,
            _           => {
                // For feelings/likes/location: store the whole message trimmed
                let trimmed = user_msg.trim().to_string();
                if trimmed.len() > 200 { trimmed[..200].to_string() } else { trimmed }
            }
        };

        eprintln!("AURA_FACT_DETECTED: {}={} (score={:.2})", key, value, best_score);
        Some((key.to_string(), value))
    }
}

fn extract_name(msg: &str) -> Option<String> {
    let prefixes = [
        "my name is ", "i'm ", "i am ", "call me ",
        "i am called ", "they call me ", "you can call me ",
    ];
    for prefix in &prefixes {
        if let Some(rest) = msg.strip_prefix(prefix) {
            let name = rest
                .split(|c: char| !c.is_alphabetic() && c != '-' && c != '\'')
                .next()
                .unwrap_or("")
                .trim();
            if !name.is_empty() && name.len() >= 2 && name.len() <= 40 {
                // Capitalise first letter
                let mut chars = name.chars();
                return Some(match chars.next() {
                    None => String::new(),
                    Some(f) => f.to_uppercase().to_string() + chars.as_str(),
                });
            }
        }
    }
    None
}

fn extract_age(msg: &str) -> Option<String> {
    for word in msg.split_whitespace() {
        let digits: String = word.chars().filter(|c| c.is_ascii_digit()).collect();
        if let Ok(age) = digits.parse::<u8>() {
            if age > 4 && age < 120 {
                return Some(age.to_string());
            }
        }
    }
    None
}