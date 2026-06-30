use crate::vision::events::{VisionDetection, VisionEvent};
use chrono::Utc;
use std::collections::HashMap;

pub struct VisionGate {
    last_seen: HashMap<String, i64>,
    cooldown_secs: i64,
    min_confidence: f32,
    min_importance: f32,
}

impl VisionGate {
    pub fn new(cooldown_secs: i64, min_confidence: f32, min_importance: f32) -> Self {
        Self {
            last_seen: HashMap::new(),
            cooldown_secs,
            min_confidence,
            min_importance,
        }
    }

    pub fn process_detections(&mut self, detections: Vec<VisionDetection>) -> Option<VisionEvent> {
        let filtered: Vec<VisionDetection> = detections
            .into_iter()
            .filter(|d| d.confidence >= self.min_confidence)
            .collect();

        if filtered.is_empty() {
            return None;
        }

        let now = Utc::now().timestamp();
        let mut important_detections = Vec::new();

        for d in &filtered {
            let last = self.last_seen.get(&d.label).cloned().unwrap_or(0);
            if now - last >= self.cooldown_secs {
                important_detections.push(d.clone());
            }
        }

        if important_detections.is_empty() {
            return None;
        }

        // Update last seen for the labels we are actually emitting
        for d in &important_detections {
            self.last_seen.insert(d.label.clone(), now);
        }

        // For now, importance is simple
        let importance = 0.6; // Milestone 1 static importance

        if importance >= self.min_importance {
            Some(VisionEvent::new(&important_detections, importance))
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vision::events::VisionDetection;
    use std::thread::sleep;
    use std::time::Duration;

    #[test]
    fn test_gate_cooldown() {
        let mut gate = VisionGate::new(1, 0.5, 0.5);
        let detections = vec![VisionDetection {
            label: "laptop".to_string(),
            confidence: 0.9,
            bbox: None,
        }];

        // First time should pass
        let event1 = gate.process_detections(detections.clone());
        assert!(event1.is_some());
        let text = event1.unwrap().text;
        assert!(text.contains("activity=computer use"));
        assert!(text.contains("objects=[laptop]"));

        // Immediate second time should be deduped
        let event2 = gate.process_detections(detections.clone());
        assert!(event2.is_none());

        // Wait for cooldown
        sleep(Duration::from_secs(2));
        let event3 = gate.process_detections(detections);
        assert!(event3.is_some());
    }

    #[test]
    fn test_gate_confidence() {
        let mut gate = VisionGate::new(1, 0.8, 0.5);
        let detections = vec![VisionDetection {
            label: "laptop".to_string(),
            confidence: 0.6,
            bbox: None,
        }];

        let event = gate.process_detections(detections);
        assert!(event.is_none());
    }
}
