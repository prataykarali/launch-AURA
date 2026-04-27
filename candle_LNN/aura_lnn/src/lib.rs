// src/lib.rs

// ── ALLOCATORS ────────────────────────────────────────────────────────────────
#[cfg(target_arch = "x86_64")]
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

#[cfg(target_arch = "aarch64")]
#[global_allocator]
static GLOBAL_ARM: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;

// ── MODULES ───────────────────────────────────────────────────────────────────
pub mod lfm2;
pub mod quantized_nn;
pub mod ct_utils;
pub mod api;
pub mod engine;        // ← only once
pub mod llm_engine;
pub mod kv_cache_io;

mod frb_generated;
mod tool_dispatcher;
mod tools;