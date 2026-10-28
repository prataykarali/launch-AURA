# AURA Project Guide

## How to Start Reading and Understanding the AURA Codebase

This guide takes you from zero to understanding the entire AURA system. Follow the reading order below.

---

## Reading Order (Start Here)

### Step 1: Understand the Architecture (30 min)
Read these files in order:

1. **`AURA_PROJECT_SUMMARY.md`** — High-level overview of the entire system
   - What AURA is (Flutter + Rust AI companion)
   - Core components (AURA Bar, Memory, Voice, Vision)
   - Current feature status

2. **`AURA_PROJECT_ROADMAP.md`** — How everything connects
   - Data flow diagrams
   - File connection map
   - Environment variables

3. **`AURA-Proj/CODEBASE_MAP.md`** — Complete file inventory
   - Every file in the project with its purpose
   - Organized by subsystem

### Step 2: Understand the Rust Engine (1-2 hours)
The Rust engine is the brain of AURA. Read in this order:

1. **`candle_LNN/aura_lnn/src/api/mod.rs`** — Public API exports
   - Lists every function exposed to Flutter
   - Shows the module structure

2. **`candle_LNN/aura_lnn/src/api/chat/turn.rs`** — Chat pipeline
   - This is THE most important file
   - Shows how a message flows through the system
   - Read lines 1-60 to understand the flow

3. **`candle_LNN/aura_lnn/src/api/chat/turn/memory.rs`** — Memory retrieval
   - How facts are gathered from the database
   - 3-tier retrieval: facts → recent turns → semantic RAG

4. **`candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs`** — Memory injection
   - How [MEMORY: ...] prefix is built
   - How facts are converted from 3rd person to 2nd person

5. **`candle_LNN/aura_lnn/src/memory/store/core.rs`** — Database schema
   - 8 tables: turns, facts, vec_memory, summaries, insights, triggers, notes, proactive_log
   - How MemoryStore::open() creates everything

6. **`candle_LNN/aura_lnn/src/api/worker_utils/rules/mod.rs`** — Fact extraction
   - How user messages become structured facts
   - 8 categories: identity, family, pets, preferences, location, goals, emotions, events

### Step 3: Understand the Memory System (1 hour)
The memory system is what makes AURA special:

1. **`candle_LNN/aura_lnn/src/memory/store/search.rs`** — Hybrid search
   - Cosine similarity + BM25 lexical scoring
   - How relevant memories are found

2. **`candle_LNN/aura_lnn/src/memory/store/facts.rs`** — Fact validation
   - What counts as a valid fact
   - How facts are structured ("User's name is X")

3. **`candle_LNN/aura_lnn/src/memory/store/mirror.rs`** — Durable persistence
   - JSONL mirror for surviving app reinstall
   - How reseed_from_file() works

4. **`candle_LNN/aura_lnn/src/memory/recall.rs`** — Memory guard
   - Consecutive-memory guard (prevents repetition)
   - Dedup and cooldown logic

### Step 4: Understand the LLM Engine (30 min)
How inference actually works:

1. **`candle_LNN/aura_lnn/src/llama_engine/model.rs`** — Model loading
   - GGUF loading via llama-cpp-2
   - Context creation

2. **`candle_LNN/aura_lnn/src/llama_engine/generate.rs`** — Token generation
   - The generation loop
   - How streaming works

3. **`candle_LNN/aura_lnn/src/llama_engine/state.rs`** — KV cache
   - Warmup (system prompt prefill)
   - Context reset

### Step 5: Understand the Persona (15 min)
How ARIA's personality is defined:

1. **`candle_LNN/aura_lnn/examples/persona_cases/system_prompt.txt`** — ARIA's personality
   - Who ARIA is (teenage girl in digital world)
   - Absolute rules (never say "As an AI")
   - Response style (1-3 sentences, warm, witty)

2. **`candle_LNN/aura_lnn/src/config/persona_bank.rs`** — Compile-time embedding
   - How persona cases are loaded into the binary

### Step 6: Understand the Flutter UI (1 hour)
How the app is structured:

1. **`aura_notebook/lib/main/launch.dart`** — App entry point
2. **`aura_notebook/lib/bar/aura_bar.dart`** — AURA Bar companion
3. **`aura_notebook/lib/services/bar_brain/`** — Bar generation logic
4. **`aura_notebook/lib/screens/`** — Main screens

---

## Key Concepts

### Prefix Injection (The Memory Magic)
AURA injects memories into the prompt BEFORE the user's message:
```
[MEMORY: your name is Luna, you love ramen, you have a cat named Mochi]
[Recent chat:
User: hi
ARIA: hey Luna! how's Mochi?
]
what's my cat's name?
```
The model sees the facts and naturally weaves them into its response.

### Fact Extraction Rules
When a user says "my name is Luna", the rules engine:
1. Detects the pattern "my name is " in the message
2. Extracts "Luna" as the value
3. Creates a structured fact: "User's name is Luna"
4. Stores it in the `facts` table
5. Embeds it for semantic search

### Hybrid Search
When searching for relevant memories:
1. Fetch structured facts (always first, highest priority)
2. Fetch recent turns (conversation continuity)
3. Semantic RAG: cosine similarity + BM25 + recency boost
4. Deduplicate and rank

### Proactive System
AURA can initiate conversations using a multi-armed bandit:
- Epsilon-greedy trigger selection
- Engagement scoring (did user respond?)
- Context-aware timing (not when user is busy)

---

## Common Tasks

### "How do I add a new fact extraction rule?"
1. Open `candle_LNN/aura_lnn/src/api/worker_utils/rules/`
2. Find the right category file (identity.rs, preferences.rs, etc.)
3. Add a new pattern match in the `extract()` function
4. Return a structured fact string

### "How do I change ARIA's personality?"
1. Edit `candle_LNN/aura_lnn/examples/persona_cases/system_prompt.txt`
2. Rebuild the Rust binary (the prompt is compile-time embedded)

### "How do I add a new memory table?"
1. Add CREATE TABLE in `candle_LNN/aura_lnn/src/memory/store/core.rs`
2. Add insert/query functions in the appropriate store file
3. Update `get_facts_strings()` or similar retrieval if needed

### "How do I change the model?"
1. Set `AURA_MODEL_PATH` environment variable
2. Or edit the default in `src/bin/sam_chat.rs` or `src/bin/aura_cli/common.rs`

### "How do I debug memory issues?"
1. Check `sqlite3 ~/.local/share/aura_notebook/aura_memory.db "SELECT * FROM facts;"`
2. Check `SELECT * FROM turns ORDER BY timestamp DESC LIMIT 10;`
3. Check `SELECT * FROM vec_memory;` for embeddings
4. Enable debug logging in `process_memory()`

---

## Architecture Decisions

### Why Rust + Flutter?
- Rust: High-performance inference, memory safety, no GC pauses
- Flutter: Cross-platform UI (Linux, Android, macOS, Windows)
- FRB: Seamless FFI bridge between the two

### Why SQLite?
- Embedded, no server needed
- WAL mode for concurrent reads
- vec_memory table stores embeddings as BLOBs
- Durable JSONL mirror for crash recovery

### Why LFM2.5-1.2B?
- Recurrent architecture (Gated Delta Net) — constant memory usage
- 1.2B parameters — fits on mobile devices
- Good persona adherence (5/10 in tests)
- Better than 450M Aria model (which has identity confusion bugs)

### Why Prefix Injection?
- Model sees facts as context, naturally integrates them
- No "I remember: ..." appendage (was repetitive and confusing)
- Facts are converted to 2nd person ("your name is X")

---

## Glossary

| Term | Meaning |
|------|---------|
| ARIA | The AI persona (teenage girl in digital world) |
| AURA Bar | Persistent companion UI (floating pill) |
| FRB | Flutter-Rust Bridge (FFI layer) |
| GGUF | Model file format (llama.cpp) |
| KV Cache | Key-Value cache for efficient generation |
| prefix injection | [MEMORY: ...] prepended to prompts |
| vec_memory | Vector embeddings table for semantic search |
| bandit | Multi-armed bandit for proactive trigger selection |
| BM25 | Lexical search algorithm (term frequency) |
| cosine similarity | Semantic search (embedding distance) |

---

## Quick Reference

### Build Commands
```bash
# Build Rust engine
cd AURA-Proj/candle_LNN/aura_lnn && cargo build --release

# Build Flutter app
cd AURA-Proj/aura_notebook && flutter run -d linux

# Run CLI
./target/release/aura_cli

# Run single message test
./target/release/sam_chat "hello"

# Run memory eval
./target/release/memory_eval
```

### Database Commands
```bash
# View all facts
sqlite3 ~/.local/share/aura_notebook/aura_memory.db "SELECT * FROM facts;"

# View recent turns
sqlite3 ~/.local/share/aura_notebook/aura_memory.db "SELECT * FROM turns ORDER BY timestamp DESC LIMIT 10;"

# View embeddings
sqlite3 ~/.local/share/aura_notebook/aura_memory.db "SELECT id, content FROM vec_memory;"

# Reset database
rm ~/.local/share/aura_notebook/aura_memory.db*
```

### Environment Variables
```bash
export AURA_MODEL_PATH="/path/to/model.gguf"
export AURA_DB_PATH="/path/to/aura_memory.db"
export AURA_CAMERA_OFF=1          # Disable camera
export AURA_PROACTIVE_OFF=1       # Disable proactive messages
export AURA_RAYON_THREADS=4       # CPU thread count
```
