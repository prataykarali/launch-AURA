// store/rows.rs - Public row structs returned by memory surfaces.

/// A durable synthesized understanding about the user.
#[derive(Clone, Debug)]
pub struct InsightRow {
    pub kind: String,        // preference / behavior / topic / pattern
    pub content: String,     // the understanding itself
    pub confidence: f32,     // 0..1, RL-shaped by engagement outcomes
    pub evidence_count: i64, // how many times re-derived
    pub source: String,      // chat / proactive / vision
    pub timestamp: i64,
}

/// One bandit/proactive event in the RL training log (visible in notebook).
#[derive(Clone, Debug)]
pub struct ProactiveLogRow {
    pub trigger_id: i64,
    pub label: String,
    pub trigger_type: String, // bandit / clock / idle / debug
    pub engaged: bool,
    pub timestamp: i64,
}

/// A user notebook note that is also mirrored into vec_memory for RAG.
#[derive(Clone, Debug)]
pub struct MemoryNoteRow {
    pub id: i64,
    pub title: String,
    pub content: String,
    pub pinned: bool,
    pub timestamp: i64,
    pub deleted: bool,
}
