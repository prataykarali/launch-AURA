// store/mod.rs - Memory store module root.
// Submodules contain the `MemoryStore` implementation and helpers.

pub mod pool;

pub mod bandit;
pub mod core;
pub mod facts;
pub mod inserts;
pub mod insights;
pub mod json_export;
pub mod maintenance;
pub mod mirror;
pub mod notebook_paired;
pub mod notebook_ro;
pub mod notes;
pub mod retrieval;
pub mod retrieval_utils;
pub mod rows;
pub mod search;
pub mod utils;
pub mod vec_memory;

pub use core::MemoryStore;
pub use rows::{InsightRow, MemoryNoteRow, ProactiveLogRow};

// Re-export public helpers so they stay at `crate::memory::store::*`.
pub use facts::split_fact_kv;
pub use utils::{
    is_amnesia_turn, is_trash_memory, is_unsafe_assistant_context, strip_speaker_prefix,
    strip_trailing_ps,
};

pub(crate) const MAX_TURN_CHARS: usize = 1_200;
pub(crate) const MAX_SUMMARY_CHARS: usize = 3_000;
pub(crate) const MAX_FACT_CHARS: usize = 220;
pub(crate) const MAX_NOTE_TITLE_CHARS: usize = 80;
pub(crate) const MAX_NOTE_CONTENT_CHARS: usize = 1_200;
pub(crate) const MAX_VEC_MEMORY_CHARS: usize = 1_500;
