// src/lib.rs

// ── ALLOCATORS ────────────────────────────────────────────────────────────────
// Each platform gets the allocator that performs best for tensor workloads.
// The default system allocator (glibc malloc on Linux, dlmalloc on Android)
// is noticeably slower for the large, long-lived allocations the KV cache
// makes — these replacements reduce allocation overhead on the hot inference
// path.

// Desktop (Linux/Windows x86_64) — mimalloc
// Microsoft's mimalloc is optimised for mixed small/large allocations.
// For candle's pattern of many small tensor ops + large KV cache blocks,
// it typically outperforms glibc malloc by 15-30%.
#[cfg(target_arch = "x86_64")]
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

// Mobile (Android aarch64) — jemalloc
// Android's default allocator is dlmalloc — it's conservative and slow
// for the large tensor allocations the model makes during warmup and
// per-turn KV cache growth. jemalloc's arena-based design handles this
// pattern much better. The disable_initial_exec_tls feature is mandatory
// for Android NDK — without it the linker throws a TLS relocation error.
#[cfg(target_arch = "aarch64")]
#[global_allocator]
static GLOBAL_ARM: tikv_jemallocator::Jemalloc = tikv_jemallocator::Jemalloc;

// ── MODULES ───────────────────────────────────────────────────────────────────
pub mod lfm2;
pub mod quantized_nn;
pub mod ct_utils;
pub mod api;
pub mod engine;
pub mod llm_engine;

mod frb_generated;
mod tool_dispatcher;
mod tools;
pub mod kv_cache_io;
