// memory/mod.rs - Simplified memory module

pub mod android_overlay;
pub mod embed;
pub mod notebook_file;
pub mod recall;
pub mod store;

pub use embed::RLScheduler;
pub use embed::{plan_reply, ReplyPlan};
pub use embed::{BgeTextEmbedder, Embedder, NoOpEmbedder, TEXT_EMBED_DIM};
pub(crate) use recall::{
    begin_memory_turn, extract_schedule_note_hint, should_inject_memory_item,
};

pub const THINKING_SENTINEL: &str = "THINKING";
