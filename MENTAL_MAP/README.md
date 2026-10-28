# AURA Mental Map (Rust + Flutter bridge)

This folder is a **human-readable dependency + dataflow map** of the AURA system so issues like:
- “AURA bar buttons not working”
- “memory layer not working (Android)”
- “TTS not working (Linux)”
- “TTS starts after text (Android)”
can be debugged by following the links below.

## How to read
- Each category has a `EXPLAIN.md` that describes:
  - **What it does**
  - **Key files**
  - **What data flows in/out**
  - **Downstream / upstream dependencies** (who calls whom)
- Use this as a “jump table” when debugging.

## Current verified links (from repo inspection)
- Bridge API module: `src/api/mod.rs` (Rust FRB exports for Flutter)
- Chat + memory injection: `src/api/engine.rs::process_chat`
- Memory persistence + extracted facts/insights: `src/api/worker_utils.rs::process_memory`
- Memory architecture & DB schema + search: `src/memory/store/mod.rs`
- Embedder + reply-length planner: `src/memory/embed.rs`
- TTS implementation: `src/api/tts.rs`

## Next debug checklist (based on observed symptoms)
- If **memory isn’t working**:
  1. Verify DB open + correct Android DB path (see `aura_init` DB resolver)
  2. Verify `process_memory()` runs after generation
  3. Verify vec embedding inserts happen (store-embed worker)
  4. Verify retrieval/search is returning non-empty results

- If **TTS is wrong on Android ordering**:
  1. TTS in Rust is async/queued; ordering is likely controlled by Flutter UI flow
  2. Confirm Flutter calls `aura_tts_speak()` early (or triggers interrupt/stop correctly)

- If **TTS isn’t working on Linux**:
  1. Check whether `aura_tts_init()` succeeded (model + audio device)
