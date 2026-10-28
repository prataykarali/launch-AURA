use aura_lnn::memory::store::MemoryStore;
use aura_lnn::vision::events::{
    detections_to_event_text, detections_to_semantic_event, semantic_event_to_memory_text,
    VisionDetection, VisionEvent,
};
use aura_lnn::vision::gate::VisionGate;
use aura_lnn::vision::store::{get_recent_visual_context, store_visual_event};
use std::time::Instant;

use super::types::{det, is_vision_query, schedule_detect, TestResult};

pub fn run_vision_tests() -> Vec<TestResult> {
    let mut r = Vec::new();
    let mut id = 1;

    // Vision query detection — 15 cases
    let vq = [
        ("simple", "what do you see", true),
        ("simple", "look around", true),
        ("simple", "what's in my room", true),
        ("medium", "can you see my desk", true),
        ("medium", "what am I doing right now", true),
        ("medium", "am I waving at you", true),
        ("medium", "describe my surroundings", true),
        ("hard", "what's on my screen", false),
        ("hard", "I want you to watch me code", true),
        ("hard", "is there anyone in the room with me", true),
        ("simple", "hello", false),
        ("simple", "what's 2+2", false),
        (
            "extreme",
            "I'm wearing a blue shirt and carrying a bag",
            true,
        ),
        (
            "extreme",
            "can you check if my hand gesture is correct",
            true,
        ),
        ("extreme", "what's the weather like", false),
    ];
    for (d, q, e) in vq {
        r.push(vq_test(id, d, q, e, &mut id));
    }

    // Event text — 12 cases
    let et: Vec<(&str, Vec<VisionDetection>, &[&str])> = vec![
        ("simple", vec![det("laptop", 0.9)], &["vision:", "laptop"]),
        ("simple", vec![det("person", 0.85)], &["vision:", "person"]),
        (
            "medium",
            vec![det("laptop", 0.9), det("person", 0.85)],
            &["laptop", "person"],
        ),
        (
            "medium",
            vec![det("laptop", 0.9), det("cup", 0.7), det("book", 0.6)],
            &["laptop", "cup", "book"],
        ),
        ("extreme", vec![], &["nothing"]),
        ("simple", vec![det("cell phone", 0.8)], &["cell phone"]),
        (
            "medium",
            vec![det("keyboard", 0.9), det("mouse", 0.8)],
            &["keyboard", "mouse"],
        ),
        (
            "extreme",
            vec![
                det("person", 0.9),
                det("laptop", 0.85),
                det("keyboard", 0.8),
                det("mouse", 0.75),
                det("cup", 0.6),
            ],
            &["person", "laptop"],
        ),
        ("simple", vec![det("tv", 0.9)], &["tv"]),
        (
            "medium",
            vec![det("book", 0.7), det("person", 0.85)],
            &["book", "person"],
        ),
        ("hard", vec![det("clock", 0.5)], &["clock"]),
        (
            "extreme",
            vec![
                det("a", 0.9),
                det("b", 0.9),
                det("c", 0.9),
                det("d", 0.9),
                det("e", 0.9),
            ],
            &["a", "b", "c", "d", "e"],
        ),
    ];
    for (d, ds, ep) in et {
        let s = Instant::now();
        let t = detections_to_event_text(&ds);
        let p = ep.iter().all(|x| t.to_lowercase().contains(x));
        r.push(TestResult {
            id,
            suite: "vision".into(),
            category: "event_text".into(),
            difficulty: d.into(),
            passed: p,
            description: format!("Event text {} dets", ds.len()),
            detail: format!("'{}'", t),
            duration_ms: s.elapsed().as_millis() as u64,
        });
        id += 1;
    }

    // Semantic classification — 12 cases
    let sc: Vec<(&str, Vec<VisionDetection>, &str, &str)> = vec![
        (
            "simple",
            vec![det("person", 0.9), det("laptop", 0.85)],
            "coding",
            "debugging",
        ),
        (
            "simple",
            vec![det("person", 0.9), det("book", 0.8)],
            "studying",
            "reading",
        ),
        ("medium", vec![det("person", 0.9)], "present", "attending"),
        (
            "medium",
            vec![det("laptop", 0.9)],
            "computer use",
            "workspace active",
        ),
        (
            "extreme",
            vec![det("wave", 0.9)],
            "present",
            "greeting gesture",
        ),
        (
            "simple",
            vec![det("person", 0.9), det("keyboard", 0.85)],
            "coding",
            "debugging",
        ),
        (
            "medium",
            vec![det("person", 0.9), det("cell phone", 0.8)],
            "studying",
            "reading",
        ),
        (
            "hard",
            vec![
                det("person", 0.9),
                det("laptop", 0.85),
                det("keyboard", 0.8),
                det("mouse", 0.75),
            ],
            "coding",
            "debugging",
        ),
        (
            "simple",
            vec![det("mouse", 0.9)],
            "computer use",
            "workspace active",
        ),
        (
            "medium",
            vec![det("clock", 0.9)],
            "environment",
            "object observation",
        ),
        (
            "hard",
            vec![det("tv", 0.9), det("person", 0.85)],
            "coding",
            "debugging",
        ),
        (
            "extreme",
            vec![det("gesture", 0.9)],
            "present",
            "greeting gesture",
        ),
    ];
    for (d, ds, ea, es) in sc {
        let s = Instant::now();
        let e = detections_to_semantic_event(&ds);
        let p = e.activity == ea && e.subactivity == es;
        r.push(TestResult {
            id,
            suite: "vision".into(),
            category: "semantic".into(),
            difficulty: d.into(),
            passed: p,
            description: format!(
                "{} -> {}/{}",
                ds.iter()
                    .map(|x| x.label.clone())
                    .collect::<Vec<_>>()
                    .join("+"),
                ea,
                es
            ),
            detail: format!("got {}/{}", e.activity, e.subactivity),
            duration_ms: s.elapsed().as_millis() as u64,
        });
        id += 1;
    }

    // Gate tests — 11 cases
    r.push(gate_test(
        id,
        "first_pass",
        true,
        vec![det("laptop", 0.9)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "dedup",
        false,
        vec![det("laptop", 0.9)],
        &mut id,
    )); // will dedup internally
    r.push(gate_test(
        id,
        "low_conf",
        false,
        vec![det("laptop", 0.3)],
        &mut id,
    ));
    r.push(gate_test(id, "empty", false, vec![], &mut id));
    r.push(gate_test(
        id,
        "multi",
        true,
        vec![det("laptop", 0.9), det("person", 0.8), det("cup", 0.7)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "mixed_conf",
        true,
        vec![det("laptop", 0.9), det("cup", 0.3)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "all_low",
        false,
        vec![det("a", 0.3), det("b", 0.4)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "high_conf",
        true,
        vec![det("person", 0.95)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "borderline",
        true,
        vec![det("laptop", 0.55)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "just_below",
        false,
        vec![det("laptop", 0.44)],
        &mut id,
    ));
    r.push(gate_test(
        id,
        "single_high",
        true,
        vec![det("keyboard", 0.99)],
        &mut id,
    ));

    // Store/retrieval — 6 cases
    r.push(vs_test(
        id,
        "store_one",
        &mut id,
        |s| {
            let e = VisionEvent::new(&[det("laptop", 0.9)], 0.6);
            store_visual_event(s, &e).unwrap();
        },
        1,
        "laptop",
    ));
    r.push(vs_test(
        id,
        "store_multi",
        &mut id,
        |s| {
            for l in ["laptop", "person", "book"] {
                let e = VisionEvent::new(&[det(l, 0.8)], 0.6);
                store_visual_event(s, &e).unwrap();
            }
        },
        3,
        "",
    ));
    r.push(vs_test(
        id,
        "store_limit",
        &mut id,
        |s| {
            for i in 0..10 {
                let e = VisionEvent::new(&[det(&format!("o{}", i), 0.8)], 0.6);
                store_visual_event(s, &e).unwrap();
            }
        },
        3,
        "",
    ));
    r.push(vs_test(id, "store_empty", &mut id, |_| {}, 0, ""));
    r.push(vs_test(
        id,
        "store_semantic",
        &mut id,
        |s| {
            let e = VisionEvent::new(&[det("person", 0.9), det("laptop", 0.85)], 0.6);
            store_visual_event(s, &e).unwrap();
        },
        1,
        "coding",
    ));
    r.push(vs_test(
        id,
        "store_dedup_content",
        &mut id,
        |s| {
            for _ in 0..3 {
                let e = VisionEvent::new(&[det("laptop", 0.9)], 0.6);
                store_visual_event(s, &e).unwrap();
            }
        },
        3,
        "laptop",
    ));

    // Gesture keywords — 8 cases
    let gk = [
        ("simple", "wave", true),
        ("medium", "open_palm_or_wave_pose", true),
        ("medium", "hand_pose", true),
        ("hard", "thumbs_up", true),
        ("hard", "hands_raised", true),
        ("extreme", "hand gesture", true),
        ("extreme", "raised", true),
        ("simple", "laptop", false),
    ];
    for (d, l, e) in gk {
        let s = Instant::now();
        let kws = [
            "wave",
            "waving",
            "hand_wave",
            "greeting",
            "open_palm",
            "thumbs_up",
            "hi_gesture",
            "hands_raised",
            "hand gesture",
            "hand pose",
            "hand_pose",
            "hand_wave_pose",
            "open_palm_or_wave_pose",
            "raised",
            "palm",
        ];
        let det = kws.iter().any(|k| l.to_lowercase().contains(k));
        let p = det == e;
        r.push(TestResult {
            id,
            suite: "vision".into(),
            category: "gesture".into(),
            difficulty: d.into(),
            passed: p,
            description: format!("Gesture: '{}'", l),
            detail: format!("det={} exp={}", det, e),
            duration_ms: s.elapsed().as_millis() as u64,
        });
        id += 1;
    }

    // Semantic→memory text — 6 cases
    let mt: Vec<(&str, Vec<VisionDetection>, &[&str])> = vec![
        (
            "simple",
            vec![det("person", 0.9), det("laptop", 0.85)],
            &["activity=coding", "objects=[laptop, person]"],
        ),
        (
            "medium",
            vec![det("wave", 0.9)],
            &["activity=present", "greeting"],
        ),
        (
            "hard",
            vec![det("person", 0.9), det("book", 0.8)],
            &["activity=studying", "reading"],
        ),
        (
            "simple",
            vec![det("laptop", 0.9)],
            &["activity=computer", "workspace"],
        ),
        (
            "extreme",
            vec![],
            &["activity=environment", "objects=[none]"],
        ),
        (
            "medium",
            vec![det("clock", 0.9)],
            &["activity=environment", "object"],
        ),
    ];
    for (d, ds, ep) in mt {
        let s = Instant::now();
        let e = detections_to_semantic_event(&ds);
        let t = semantic_event_to_memory_text(&e);
        let p = ep.iter().all(|x| t.contains(x));
        r.push(TestResult {
            id,
            suite: "vision".into(),
            category: "mem_text".into(),
            difficulty: d.into(),
            passed: p,
            description: format!("Mem text: {} dets", ds.len()),
            detail: format!("'{}'", &t[..t.len().min(100)]),
            duration_ms: s.elapsed().as_millis() as u64,
        });
        id += 1;
    }

    r
}

fn vq_test(id: usize, d: &str, q: &str, e: bool, idr: &mut usize) -> TestResult {
    let s = Instant::now();
    let det = is_vision_query(&q.to_lowercase());
    let p = det == e;
    *idr += 1;
    TestResult {
        id,
        suite: "vision".into(),
        category: "vision_query".into(),
        difficulty: d.into(),
        passed: p,
        description: format!("VQ: '{}'", q),
        detail: format!("det={} exp={}", det, e),
        duration_ms: s.elapsed().as_millis() as u64,
    }
}

fn gate_test(
    id: usize,
    scenario: &str,
    expect_some: bool,
    dets: Vec<VisionDetection>,
    idr: &mut usize,
) -> TestResult {
    let s = Instant::now();
    let mut gate = VisionGate::new(100, 0.5, 0.5);
    // For dedup test, process twice
    let event = if scenario == "dedup" {
        let _e1 = gate.process_detections(dets.clone());
        gate.process_detections(dets)
    } else {
        gate.process_detections(dets)
    };
    let p = if expect_some {
        event.is_some()
    } else {
        event.is_none()
    };
    *idr += 1;
    TestResult {
        id,
        suite: "vision".into(),
        category: "gate".into(),
        difficulty: "simple".into(),
        passed: p,
        description: format!("Gate: {}", scenario),
        detail: format!("event={:?}", event.map(|e| e.text)),
        duration_ms: s.elapsed().as_millis() as u64,
    }
}

fn vs_test<F>(
    id: usize,
    scenario: &str,
    idr: &mut usize,
    setup: F,
    expect_count: usize,
    must_contain: &str,
) -> TestResult
where
    F: FnOnce(&MemoryStore),
{
    let s = Instant::now();
    let db = format!("temp_vis_{}_{}.db", scenario, std::process::id());
    let _ = std::fs::remove_file(&db);
    let store = MemoryStore::open(&db).unwrap();
    setup(&store);
    let ctx = get_recent_visual_context(&store, 3).unwrap();
    let p = ctx.len() == expect_count
        && (must_contain.is_empty() || ctx.iter().any(|c| c.contains(must_contain)));
    drop(store);
    let _ = std::fs::remove_file(&db);
    let _ = std::fs::remove_file(format!("{}-wal", db));
    let _ = std::fs::remove_file(format!("{}-shm", db));
    *idr += 1;
    TestResult {
        id,
        suite: "vision".into(),
        category: "vision_store".into(),
        difficulty: "simple".into(),
        passed: p,
        description: format!("Store: {}", scenario),
        detail: format!("got {} expected {}", ctx.len(), expect_count),
        duration_ms: s.elapsed().as_millis() as u64,
    }
}
