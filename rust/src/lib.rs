#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

// Your existing modules
pub mod tool_dispatcher;
pub mod tools;
pub mod llm_engine;

// Flutter bridge module
pub mod bridge;

// Re-export for Flutter
pub use bridge::*;