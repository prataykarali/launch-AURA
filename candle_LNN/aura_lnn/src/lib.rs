// src/lib.rs
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;
mod frb_generated;   // codegen output — never edit manually
pub mod api;
pub mod engine;
pub mod llm_engine;  // your existing get_device() lives here
mod tool_dispatcher;
mod tools;