# LLM Engine Subsystem

## Overview
The LLM engine wraps llama.cpp (via llama_cpp_2) to run the chat model (Gated Delta Net recurrent architecture, 1.2B). It manages the KV/recurrent cache, sampler chain, and a background store-embed worker that shares the dedicated bge embedder.

## Core Files

### `candle_LNN/aura_lnn/src/llama_engine.rs`
**Key Struct: `LlamaEngine`**
- `model: &'static LlamaModel`
- `context: LlamaContext<'static>`
- `sampler: LlamaSampler`
- `system_tokens: Vec<LlamaToken>` (prefilled system prompt)
- `n_past: i32` (recurrent state position)
- `embedder: Arc<BgeTextEmbedder>` (shared with store-embed worker)
- `store_embed_tx: Option<SyncSender<StoreEmbedJob>>`

**Static:**
- `CANCEL_FLAG: AtomicBool` — set by `aura_cancel()` from Dart to abort generation.

### Functions

| Function | Purpose | Affects / Affected By |
|----------|---------|----------------------|
| `new(model_path, _backend, n_ctx, n_threads, embedder)` | Load model + context + sampler + spawn store-embed worker | Called by `engine.rs:aura_init`. If you change params here, update `aura_init` worker spawn + `config::n_ctx_for_platform`. |
| `warmup()` | Prefill system prompt into KV cache (caches system_tokens) | Called on init and on every context reset. Touch `config::persona::SYSTEM_PROMPT` → must re-warmup. |
| `generate_stream(prompt, on_token)` | Thin wrapper → `generate_with_context` with empty memories | Legacy/CLI path. |
| `generate_with_context(prompt, memories, max_new_tokens, on_token)` | MAIN GENERATION. Injects memories as system message, decodes user prompt, streams tokens, handles think tags (`<|think|>`/`</>`), EOS detection, context reset at low watermark. | Called by `engine.rs:process_chat`. change `memories` shape → update `engine.rs` context assembly. change reset thresholds → affects latency ramp. |
| `generate_continue(max_new_tokens, on_token)` | Continue from last n_past (no re-decode) for variable-length planner | Called when `ReplyPlan.continuation > 0`. |
| `reset_state()` | Clear KV cache + system_tokens + n_past | Called on context overflow + `EngineMsg::ResetState`. |
| `clear_kv_cache()` | Just clear cache | Diagnostic. |
| `prefill(_partial)` | DISABLED (recurrent model can't partial-rewind) | No-op. Changing this is risky. |
| `embedder()` | Return shared bge embedder Arc | Used by `engine.rs` worker dispatch for SearchRelevant/AddMemoryNote. |
| `embed_query(text)` | Embed a query via bge | Called by `engine.rs:process_chat` (semantic RAG). |
| `store_embed(text, store)` | Fire-and-forget enqueue turn to background worker | Called by `engine.rs` after generating a response. Changing queue size (8) affects backpressure. |
| `is_stop_token(token_id)` | Check EOS/im_end | Detects `<|im_end|>`, `</s>`, `` |
| `spawn_store_embed_worker(embedder)` | Background thread: embed_passage + insert_vec_memory | If this fails, store_embed_tx=None and RAG degrades to recency-only. |

### `candle_LNN/aura_lnn/src/api/engine.rs` - Worker & Dispatch
**Key Globals:**
- `TX: OnceCell<SyncSender<EngineMsg>>` — the single worker channel
- `DB_PATH: OnceCell<String>` — stable DB path
- `MODEL_DIR: OnceCell<String>` — model directory

**EngineMsg variants** (defined in `api/mod.rs`):
`Chat`, `ChunkedChat`, `ResetState`, `BufferStatus`, `GetProactiveContext`, `CheckScheduler`, `RecordEngagement`, `SearchRelevant`, `LogProactive`, `AddMemoryNote`, `DeleteMemoryNote`, `GetHistory`, `GetSummaries`, `GetFacts`...

**Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `aura_init(model_path, tokenizer_path, embed_model_path, embed_tok_path)` | Spawn worker thread, load engine + embedder + memory_store, init STT | Entry point from Flutter. Change params → update `loading_screen.dart` + `main.dart`. |
| `aura_get_available_backends()` | List device backends | UI backend picker. |
| `aura_set_backend/threads/context_size()` | Stubs (log only) | Config UI. |
| `aura_clear_memory()` | Delete DB file | Settings. |
| `resolve_db_path(model_dir)` | Stable DB path (Android/Linux) | All memory operations. |
| `process_chat(engine, memory_store, prompt, sink, cached_memories)` | MAIN CHAT PIPELINE. Strips [BRIEF], fast-path for greetings/short queries, plans reply, assembles memories (facts+RAG+turns+insights), generates, amnesia guard, stores turn + process_memory. | The heart of chat. Touch memory assembly → touch this. |
| `build_grounded_reply(prompt_lower, facts)` | Override amnesia responses with fact-based reply | Called from process_chat amnesia guard. |
| `humanize_fact(fact)` | Convert stored fact to natural speech | Used by build_grounded_reply. |
| `cap_memory_item(s, max_chars)` | Truncate memory to char budget | Used in context assembly. |

### `candle_LNN/aura_lnn/src/config/` - Configuration
| File | Purpose | Affects |
|------|---------|---------|
| `constants.rs` | `REPEAT_LAST_N`, `REPEAT_PENALTY`, `TOP_P`, `TEMPERATURE`, `THINKING_SENTINEL` | Sampler chain in `LlamaEngine::new`. |
| `persona.rs` | `SYSTEM_PROMPT` | Warmup + every context reset. |
| `mod.rs` | `configure_rayon_threads()`, `n_ctx_for_platform()` | `aura_init`, context size per platform. |

### `candle_LNN/aura_lnn/src/device_backend.rs`
| Function | Purpose | Affects |
|----------|---------|---------|
| `DeviceBackend::available()` | List CPU/Accel backends | Backend picker UI. |
| `default_for_platform()` | Pick backend | `aura_init` engine creation. |
| `n_threads_for_platform()` | Thread count | Engine context params. |

## Adding a Feature — What to Change

| Want to... | Change |
|-----------|--------|
| New EngineMsg type | `api/mod.rs` enum + `engine.rs` worker match + `api/<area>.rs` sender + `src/rust/api.dart` (frb generated) |
| Different system prompt | `config/persona.rs::SYSTEM_PROMPT` (auto re-warmup on reset) |
| Bigger/smaller context window | `config::n_ctx_for_platform()` + `RESET_MARGIN_FRAC` in generate_with_context |
| New sampler param | `config/constants.rs` + `LlamaEngine::new` sampler chain |
| Change memory injection order | `engine.rs:process_chat` (facts → RAG → turns → insights) |
| Add embedder modality (vision) | New impl of `Embedder` trait in `embed.rs`, separate dim/table |
| Variable-length planner | `embed.rs:plan_reply` + `ReplyPlan.continuation` + `generate_continue` |
| Cancel generation | `CANCEL_FLAG` (set from Dart `auraCancel`) |

## Data Flow

```
Flutter auraChat(prompt) → TX channel → worker rx
  → process_chat:
      plan_reply() → max_tokens
      memory_store.get_facts_strings()
      engine.embed_query() → store.search_relevant()
      store.recent_turn_strings_filtered()
      store.get_insight_strings()
      engine.generate_with_context(prompt, memories, max_tokens, on_token)
          → on_token → sink → Flutter stream
      store.insert_turn("assistant", response)
      engine.store_embed(response, store)  [background]
      process_memory(store, prompt, response)
```
