// src/lib.rs
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;
pub mod lfm2;
mod frb_generated;   // codegen output — never edit manually
pub mod api;
pub mod engine;
pub mod llm_engine;  // your existing get_device() lives here
mod tool_dispatcher;
mod tools;pub mod quantized_nn;
pub mod ct_utils;
