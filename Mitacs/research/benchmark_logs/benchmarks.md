# AURA — Benchmark Log

Machine: Aspire A515-58GM, Ubuntu Linux (dev machine)
Note: These are dev-machine numbers. Real paper figures come from phone runs (Phase 3).
These establish the *claim* — phone runs confirm the *magnitude*.

---

## B1 — Layer 1 Facts Cache: HashMap vs SQLite

**Date:** May 31 2026  
**File:** `src/memory/store.rs` — `facts_cache_vs_sqlite_benchmark()`  
**What:** 1000 lookups of `user_name` from 20 facts, in-memory SQLite DB  

| Path | Time (1000 lookups) | Per lookup |
|---|---|---|
| SQLite `SELECT WHERE key=?` | ~6800 µs | ~6.8 µs |
| `HashMap::get()` | ~250 µs | ~0.25 µs |
| **Speedup** | **~28x** | |

**Claim:** Layer 1 facts cache delivers O(1) lookup at session start vs repeated SQL queries.  
**Paper section:** R2 — Memory system design.  
**To-do:** Rerun on phone (Pixel / iPhone) in Phase 3 for real device numbers.

---

---

## Research Crate Status (May 31 2026)

`src/research/` scaffold is live behind `--features research`.

| File | Status | Wires into | Phase |
|---|---|---|---|
| `latency.rs` | stub — `log_to_csv()` writes CSV | `infer_stream()` — record TTFT, tok/s per turn | Phase 3 |
| `ablation.rs` | stub — `AblationFlags` with AtomicBool | `engine.rs` — skip memory/tools/cache per flag | Phase 3 |
| `benchmark.rs` | stub — `BenchmarkRunner` + `export_csv()` | 50 fixed prompts → CSV | Phase 3 |

**B1 (HashMap speedup) is the first real number in this file.**
Next real number will be TTFT on phone — goes in latency.rs → aura_latency.csv.


---

## PHASE 2 GATE — PASSED ✅ May 31 2026

AURA correctly recalled user name "Pratay" from previous session
without being told this session. Cross-session memory via HashMap
injection confirmed working end-to-end.

Gate was: "AURA remembers your name next session" (target Jun 15)
Achieved: May 31 — 2 weeks early.

---

## B2 — DSA Micro-benchmarks: Ring Buffer, Sliding Window, Priority Queue
**Date:** Jun 7 2026  
**Machine:** Aspire A515-58GM, Ubuntu Linux  
**File:** `src/research/benchmark.rs` — `bench_ring_buffer()`, `bench_sliding_window()`, `bench_priority_queue()`  
**N:** 100,000 ops each

| Structure | Debug total | Debug ns/op | Release total | Release ns/op | Role in AURA |
|---|---|---|---|---|---|
| Ring Buffer (VecDeque cap 8) | 4.57ms | 46 ns | ~100µs | 1 ns | PCM capture for Picovoice VAD (F3) |
| Sliding Window (VecDeque cap 20) | 5.99ms | 60 ns | ~109µs | 1 ns | Prefill gate ≥6 words (F1) + VAD (F3) |
| Priority Queue (BinaryHeap cap 8) | 25.51ms | 255 ns | ~750µs | 7–8 ns | Notification + proactive scheduler (F3/F4) |

**Key observations:**
- Release is ~40–46× faster than debug for Ring Buffer and Sliding Window — compiler vectorises the tight VecDeque loop completely
- Priority Queue is ~32× faster in release but still ~7× slower than Ring Buffer per op — correct, BinaryHeap::push is O(log n) vs VecDeque O(1)
- All three are well within real-time budget: at 16kHz audio, one PCM frame arrives every 62µs — Ring Buffer at 1 ns/op is 62× faster than needed
- Release ns/op hitting 1 ns means the loop is memory-bound, not compute-bound — good for mobile

**Paper claim:** All three DSA structures operate below 10 ns/op in release, making them safe for the audio and inference hot paths with zero latency contribution.  
**To-do:** Rerun on phone (aarch64) in Phase 3 — ARM NEON vectorisation may change the profile.

---

## B3 — aura_benchmark.csv Pipeline: Stub Run
**Date:** Jun 7 2026  
**Command:** `cargo run --bin benchmark --features research`  
**Result:** 17 rows written to `aura_benchmark.csv`  

All ttft_ms = 0 and tokens_per_sec = millions — expected. Stub closure has no real inference, so elapsed ≈ 0 and division by near-zero gives garbage tok/s. Pipeline correctness confirmed: prompts → `run<F>` → `BenchmarkResult` → `export_csv()` → CSV.

Phase 3: swap closure body for real `infer_stream()` call → real numbers.  
TODO before Phase 3 gate: pad prompt list from 17 → 50.

---

## aura_research Scaffold — COMPLETE ✅ Jun 7 2026

| File | Status |
|---|---|
| `latency.rs` | ✅ real — `log_to_csv()` with header guard |
| `ablation.rs` | ✅ real — `AblationFlags` with `set_memory/tools/cache()` |
| `benchmark.rs` | ✅ real — 17 prompts, `run<F>` closure, `export_csv()`, 3 DSA micro-benchmarks |

Next: Picovoice + Rive always-on bar (Jun 9–15).

---

## B4 — Memory Recall Accuracy & Core LLM RAG Performance
**Date:** Jun 25 2026  
**File:** `src/bin/memory_test.rs` — `memory_test` harness  
**What:** 500 generated test cases evaluating memory recall on LFM 230M and BGE embedder

| Metric | Value |
|---|---|
| **Total Test Cases** | 500 |
| **Passed Cases** | 355 |
| **Failed Cases** | 145 |
| **Overall Accuracy** | **71.00%** |
| **Harness Execution Time** | 966.01s |

### Accuracy by Evaluation Category:

| Category | Difficulty | Accuracy | Description |
|---|---|---|---|
| `preference_recall` | Simple | **95.00%** | Recalling item user likes/dislikes (e.g. food/sport) |
| `name_recall` | Simple | **94.00%** | Recalling user's name introduced in Turn 1 |
| `multi_turn_recall` | Hard | **78.00%** | Recalling name/preference after 3 filler chat turns |
| `complex_synthesis` | Very Hard | **54.00%** | Synthesizing name, location, job, and preference |
| `distractor_robustness` | Medium/Hard | **34.00%** | Ignoring background distractors about others |

**Speed & Latency Aggregate:**
- Warmup Time: ~350ms (average cold/warm warmup)
- Generation Speed: ~75–93 tokens/s (230M model on CPU release build)
- TTFT: ~245–450ms (average user prompt decoding + context loading)

**Analysis of Failures:**
1. **Formatting**: Small model occasionally violated no-markdown rule, outputting formatting that took extra tokens.
2. **Verbosity**: With `max_new_tokens` capped at 64, synthesis often ran out of token budget before completing.
3. **Strict Evaluation**: Distractor cases failed strictly if distractor words appeared in response (even if model correctly recalled user details).