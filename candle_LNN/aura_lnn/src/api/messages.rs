use crate::frb_generated::StreamSink;
use crate::vision::VisionDetection;
use std::sync::mpsc;

#[allow(dead_code)]
pub(crate) enum EngineMsg {
    Chat {
        prompt: String,
        sink: StreamSink<String>,
    },
    ChunkedChat {
        chunks: Vec<String>,
        sink: StreamSink<String>,
    },
    Prefill {
        partial: String,
    },
    Inject {
        _context: String,
    },
    VisionEvent {
        detections: Vec<VisionDetection>,
    },
    GetHistory {
        reply: mpsc::SyncSender<String>,
    },
    GetSummaries {
        reply: mpsc::SyncSender<String>,
    },
    GetFacts {
        reply: mpsc::SyncSender<String>,
    },
    ResetState,
    BufferStatus {
        reply: mpsc::SyncSender<String>,
    },
    GetProactiveContext {
        reply: mpsc::SyncSender<String>,
    },
    CheckScheduler {
        reply: mpsc::SyncSender<Option<String>>,
    },
    RecordEngagement {
        trigger_id: i64,
        engaged: bool,
        reply: mpsc::SyncSender<bool>,
    },
    SearchRelevant {
        query: String,
        limit: usize,
        reply: mpsc::SyncSender<String>,
    },
    // ── New memory surfaces (insights / proactive log / memory notes) ──────
    LogProactive {
        trigger_id: i64,
        label: String,
        trigger_type: String,
        engaged: bool,
        reply: mpsc::SyncSender<bool>,
    },
    AddMemoryNote {
        title: String,
        content: String,
        pinned: bool,
        reply: mpsc::SyncSender<i64>,
    },
    UpdateMemoryNote {
        id: i64,
        title: String,
        content: String,
        pinned: bool,
        deleted: bool,
        reply: mpsc::SyncSender<bool>,
    },
    DeleteMemoryNote {
        id: i64,
        reply: mpsc::SyncSender<bool>,
    },
    RecoverMemoryNote {
        id: i64,
        reply: mpsc::SyncSender<bool>,
    },
    DeleteMemoryNotePermanently {
        id: i64,
        reply: mpsc::SyncSender<bool>,
    },
    /// File sense: read a text/Markdown file into vec_memory for RAG retrieval.
    /// Analogous to the STT sense (audio → text → memory) but for files.
    ReadFileIntoMemory {
        path: String,
        label: Option<String>,
        reply: mpsc::SyncSender<bool>,
    },
    /// Memory-pressure auto-heal: run cache clears, turn summarization, and
    /// other safe cleanup steps. The optional reply channel carries a JSON
    /// status string.
    HealMemory {
        reply: Option<mpsc::SyncSender<String>>,
    },
}
