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

