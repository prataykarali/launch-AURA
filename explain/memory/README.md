# Memory Subsystem

## Overview
The memory subsystem is the core of AURA's persistent knowledge. It uses SQLite with WAL mode for concurrent reads/writes, stores conversation turns, facts, summaries, vector embeddings for RAG, insights, proactive triggers, and memory notes.

## Core Files

### `candle_LNN/aura_lnn/src/memory/store/mod.rs` - Main Memory Store
**Key Struct: `MemoryStore`** (pool: Arc<ConnPool>, mirror: Option<Arc<NotebookMirror>>)

**Tables:**
- `turns` - conversation turns (speaker, content, timestamp)
- `summaries` - conversation summaries
- `facts` - extracted identity/preference facts (ALWAYS injected into context)
- `vec_memory` - vector embeddings for semantic RAG
- `triggers` - RL bandit triggers with engagement scores
- `insights` - synthesized understandings (kind, content, confidence, evidence_count)
- `proactive_log` - RL timeline of proactive events
- `memory_notes` - user-pinned notes (also mirrored to vec_memory)

**Core Functions:**

| Function | Purpose | Dependencies |
|----------|---------|--------------|
| `open(db_path)` | Initialize DB, run schema, seed triggers | `ConnPool`, `NotebookMirror` |
| `insert_turn(speaker, content)` | Store turn + mirror to notebook file | `strip_speaker_prefix()` |
| `insert_fact(fact)` | Store fact + mirror | - |
| `insert_summary(summary)` | Store summary + mirror | - |
| `insert_vec_memory(content, embedding)` | Store embedding for RAG | Called by background worker |
| `search_relevant(query_embedding, limit)` | Semantic RAG - cosine similarity | Used by `engine.rs:process_chat` |
| `recent_turn_strings(keep)` | Last N turns for continuity | Used by `engine.rs:process_chat` |
| `recent_turn_strings_filtered(keep)` | Filtered (no amnesia turns) | Used by chat context |
| `get_facts_strings(limit)` | Identity/preference facts | ALWAYS injected first |
| `get_recent_summaries_strings(limit)` | Mid-term summaries | Injected after facts |
| `search_memory(query_embedding, limit)` | Hybrid: semantic + priority buckets | Legacy, used by proactive |
| `get_recent_memories(limit)` | Balanced mix (facts/summaries/turns) | No embedding needed |
| `get_proactive_context()` | Compact context for proactive prompts | Facts + summary + recent turns |
| `turn_count()` | Turn count for summarization cap | Used by BufferStatus |
| `compute_drift(recent_n)` | Topic drift from vec_memory centroid | Used by BufferStatus |
| `summarize_history(keep, fold_n)` | Fold old turns into summary | Called by `worker_utils:process_memory` |
| `trim_turns(keep)` | Delete old turns | Called by summarize_history |
| `upsert_insight(kind, content, delta, source)` | Insert/update insights | Called by `worker_utils:extract_insights` |
| `record_engagement(trigger_id, engaged)` | Update RL bandit scores | Called by `bar_brain.dart` |
| `get_proactive_suggestion()` | Epsilon-greedy trigger selection | Called by `bar_brain.dart` |
| `mark_trigger_fired(trigger_id)` | Update cooldown timestamp | Called by proactive system |
| `mirror_append(record)` | Append to durable JSONL notebook | All write paths |
| `turn_exists/summary_exists/note_exists` | Dedup for re-seed | Used on fresh install |

### `candle_LNN/aura_lnn/src/memory/embed.rs` - Dedicated Embedder
**Key Struct: `BgeTextEmbedder`** (session: Mutex<Session>, tokenizer: Mutex<Tokenizer>)

**Constants:**
- `TEXT_EMBED_DIM = 384` (bge-small-en-v1.5)

**Functions:**

| Function | Purpose | Called By |
|----------|---------|-----------|
| `new(model_path, tokenizer_path)` | Load ONNX + tokenizer | `engine.rs:aura_init` |
| `embed_passage(content)` | Embed for STORAGE (raw text) | `llama_engine.rs:store_embed` |
| `embed_query(query)` | Embed for QUERY (with instruction) | `engine.rs:process_chat`, `api/memory.rs` |
| `embed_inner(text)` | Tokenize → ONNX → CLS pool → L2 normalize | Both embed methods |
| `plan_reply(prompt, is_mobile)` | Classify prompt → ReplyPlan (length/continuation) | `engine.rs:process_chat` |
| `RLScheduler` | Bandit scheduler (delegates to MemoryStore) | `engine.rs` init |

**ReplyPlan Levels (0-6):**
- 0: Greeting (48/40 desktop/mobile tokens)
- 1: Identity/pref (96/64)
- 2: Simple Q (160/96)
- 3: Real Q (256/160)
- 4: Detailed Q (384/224)
- 5: Deep Q/List (576/320, 1 continuation)
- 6: Explain/Write (768/448, 2 continuations)

### `candle_LNN/aura_lnn/src/memory/notebook_file.rs` - Durable Mirror
**Purpose:** Uninstall-safe JSONL transcript at `~/.local/share/aura_notebook/notebook.jsonl`

**Functions:**
- `open(app_data_dir)` - Open/create mirror file
- `append(record)` - Append NotebookRecord
- `reseed_from_file(store)` - Re-seed DB on fresh install (dedups via turn_exists, etc.)

### `candle_LNN/aura_lnn/src/memory/store/pool.rs` - Connection Pool
**Key Struct: `ConnPool`** with WAL mode, busy timeout, pooled connections

### `candle_LNN/aura_lnn/src/memory/android_overlay.rs` - Android Overlay Config
**Functions:**
- `aura_get_overlay_config()` - Returns overlay position/size JSON

## Data Flow

```
User Prompt → engine.rs:process_chat
    → memory_store.get_facts_strings() [ALWAYS first]
    → embedder.embed_query() → memory_store.search_relevant() [semantic RAG]
    → memory_store.recent_turn_strings_filtered() [continuity]
    → memory_store.get_insight_strings() [behavioral patterns]
    → Inject all into LLM context
    → LLM generates response
    → memory_store.insert_turn("assistant", response)
    → llama_engine.store_embed() [background worker embeds turn]
    → worker_utils.process_memory() [extract facts/insights/summarize]
        → memory_store.insert_fact()
        → memory_store.upsert_insight()
        → memory_store.insert_summary()
        → memory_store.summarize_history()
```

## Dependencies

| Component | Depends On | Affects |
|-----------|------------|---------|
| `MemoryStore` | `ConnPool`, `NotebookMirror` | All memory operations |
| `BgeTextEmbedder` | ONNX Runtime, tokenizers | RAG quality, drift detection |
| `RLScheduler` | `MemoryStore` | Proactive trigger selection |
| `NotebookMirror` | File system | Durability across reinstalls |
| Background worker | `BgeTextEmbedder`, `MemoryStore` | Async vec_memory population |
| `engine.rs` | `MemoryStore`, `BgeTextEmbedder` | Chat context assembly |
| `api/memory.rs` | `MemoryStore`, `TX` channel | Notebook UI reads |
| `worker_utils.rs` | `MemoryStore` | Fact/insight extraction |

## Key Design Decisions

1. **Dedicated embedder (bge-small)** - Replaces noisy chat-model mean-pooled embeddings
2. **Facts table** - Always injected verbatim (not subject to RAG budget trimming)
3. **Background store-embed worker** - Chat thread never waits for embeddings
4. **Durable JSONL mirror** - Survives uninstall/reinstall
5. **Insights vs Facts** - Facts = identity/prefs; Insights = behavioral patterns
6. **Mechanical summarization** - No LLM call, folds old turns every 6 turns
7. **Topic drift detection** - Centroid cosine distance from recent vec_memory
8. **Expanded Mental Model** - Heuristics in `worker_utils.rs` extract and upsert dynamic insights representing user mood/emotional patterns, routines (time of day), and core interests (coding/academics) directly into the `insights` table.