pub(crate) mod chat;
pub(crate) mod config;
pub(crate) mod engine;
pub(crate) mod file_read;
pub(crate) mod memory;
pub(crate) mod messages;
pub(crate) mod stt;
pub(crate) mod tts;
pub(crate) mod vision;
pub mod worker_utils;

use std::sync::mpsc;
use std::sync::OnceLock;

pub(crate) use messages::EngineMsg;

pub(crate) static TX: OnceLock<mpsc::SyncSender<EngineMsg>> = OnceLock::new();
pub(crate) static DB_PATH: OnceLock<String> = OnceLock::new();
pub(crate) static MODEL_DIR: OnceLock<String> = OnceLock::new();

pub use chat::turn::build_memory_prefix;
pub use chat::turn::build_recall_prefill;
pub use chat::{
    aura_cancel, aura_chat, aura_chat_chunked, aura_inject, aura_prefill, aura_reset_state,
};
pub use config::{configure_rayon_threads, n_ctx_for_platform, smooth_performance_label};
pub use engine::{
    aura_clear_memory, aura_get_available_backends, aura_init, aura_set_backend,
    aura_set_context_size, aura_set_threads,
};
pub use file_read::aura_read_file_into_memory;
pub use memory::{
    aura_add_memory_note, aura_check_memory_health, aura_check_proactive, aura_delete_memory_note,
    aura_delete_memory_note_permanently, aura_get_all_facts_json, aura_get_all_notebook_turns,
    aura_get_all_summaries_json, aura_get_buffer_status, aura_get_memory_notes_json,
    aura_get_notebook_insights_json, aura_get_notebook_proactive_log_json, aura_get_overlay_config,
    aura_get_proactive_context, aura_log_proactive, aura_record_engagement,
    aura_recover_memory_note, aura_search_relevant, aura_update_memory_note,
};
pub use stt::{aura_stt_available, aura_stt_init, aura_stt_push_audio, aura_stt_reset_session};
pub use tts::{
    aura_tts_available, aura_tts_init, aura_tts_set_volume, aura_tts_speak, aura_tts_stop, TtsAudio,
};
pub use vision::{
    aura_get_latest_webcam_scene, aura_get_recent_visual_context, aura_get_webcam_gesture,
    aura_process_vision, aura_start_webcam_thread, aura_stop_webcam_thread,
};
