fn now_timestamp() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VisionDetection {
    pub label: String,
    pub confidence: f32,
    pub bbox: Option<[f32; 4]>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VisionEvent {
    pub text: String,
    pub timestamp: i64,
    pub importance: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SemanticVisionEvent {
    pub timestamp: i64,
    pub activity: String,
    pub subactivity: String,
    pub screen: String,
    pub text: String,
    pub objects: Vec<String>,
    pub importance: String,
    pub confidence: f32,
    pub source: String,
}

pub fn detections_to_event_text(detections: &[VisionDetection]) -> String {
    if detections.is_empty() {
        return "vision: nothing of note detected".to_string();
    }

    let mut labels: Vec<String> = detections.iter().map(|d| d.label.clone()).collect();
    labels.sort();
    labels.dedup();

    if labels.len() == 1 {
        format!("vision: {} visible", labels[0])
    } else if labels.len() == 2 {
        format!("vision: {} and {} visible", labels[0], labels[1])
    } else {
        let last = labels.pop().unwrap();
        format!("vision: {}, and {} visible", labels.join(", "), last)
    }
}

pub fn detections_to_semantic_event(detections: &[VisionDetection]) -> SemanticVisionEvent {
    let mut objects: Vec<String> = Vec::new();
    let mut screen_text = String::new();

    for d in detections {
        if d.label.starts_with("ocr_text:") {
            screen_text = d.label[9..].trim().to_string();
        } else {
            objects.push(d.label.clone());
        }
    }
    objects.sort();
    objects.dedup();

    let vision_detections: Vec<&VisionDetection> = detections
        .iter()
        .filter(|d| !d.label.starts_with("ocr_text:"))
        .collect();
    let confidence = if vision_detections.is_empty() {
        0.0
    } else {
        vision_detections.iter().map(|d| d.confidence).sum::<f32>() / vision_detections.len() as f32
    }
    .clamp(0.0, 1.0);

    let has = |label: &str| objects.iter().any(|object| object == label);
    let has_contains = |needle: &str| {
        objects
            .iter()
            .any(|object| object.to_ascii_lowercase().contains(needle))
    };
    let has_any = |labels: &[&str]| labels.iter().any(|label| has(label));

    let (activity, subactivity) = if has_contains("wave")
        || has_contains("gesture")
        || has_contains("hand_pose")
        || has_contains("hands_raised")
        || has_contains("open_palm")
    {
        ("present", "greeting gesture")
    } else if has("person") && has_any(&["laptop", "keyboard", "mouse", "tv"]) {
        ("coding", "debugging")
    } else if has("person") && has_any(&["book", "cell phone"]) {
        ("studying", "reading")
    } else if has("person") {
        ("present", "attending")
    } else if has_any(&["laptop", "keyboard", "mouse", "tv"]) {
        ("computer use", "workspace active")
    } else {
        ("environment", "object observation")
    };

    let screen = if has("laptop") {
        "laptop"
    } else if has("tv") {
        "monitor"
    } else if has("cell phone") {
        "phone"
    } else {
        "unknown"
    };

    let importance = if confidence >= 0.85 {
        "high"
    } else if confidence >= 0.55 {
        "medium"
    } else {
        "low"
    };

    let has_screen_text = !screen_text.is_empty();

    SemanticVisionEvent {
        timestamp: now_timestamp(),
        activity: activity.to_string(),
        subactivity: subactivity.to_string(),
        screen: screen.to_string(),
        text: screen_text,
        objects,
        importance: importance.to_string(),
        confidence,
        source: if has_screen_text { "screen" } else { "camera" }.to_string(),
    }
}

pub fn semantic_event_to_memory_text(event: &SemanticVisionEvent) -> String {
    let objects = if event.objects.is_empty() {
        "none".to_string()
    } else {
        event.objects.join(", ")
    };

    format!(
        "vision: activity={} subactivity={} source={} screen={} objects=[{}] text=\"{}\" importance={} confidence={:.2}",
        event.activity,
        event.subactivity,
        event.source,
        event.screen,
        objects,
        event.text,
        event.importance,
        event.confidence,
    )
}

impl VisionEvent {
    pub fn new(detections: &[VisionDetection], importance: f32) -> Self {
        let semantic = detections_to_semantic_event(detections);
        Self {
            text: semantic_event_to_memory_text(&semantic),
            timestamp: semantic.timestamp,
            importance,
        }
    }
}
