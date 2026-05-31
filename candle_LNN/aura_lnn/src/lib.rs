// src/lib.rs

// ── ALLOCATORS ────────────────────────────────────────────────────────────────


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
pub mod config;
pub mod memory;

mod frb_generated;
mod tools;
#[cfg(feature = "research")]
pub mod research;