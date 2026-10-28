# AURA Project Roadmap & Mental Map

## How Everything Connects

This document shows how every major file in the AURA project connects to everything else. Use it as your navigation guide.

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER UI LAYER                            │
│  aura_notebook/lib/                                                │
│  ├── main.dart → aura_app.dart → aura_root.dart                   │
│  ├── bar/ (AURA Bar companion)                                     │
│  ├── screens/ (Home, Notebook, Loading, Options)                   │
│  └── services/ (TTS, STT, BarBrain, Proactive)                    │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Flutter-Rust Bridge (FRB)
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        RUST ENGINE LAYER                           │
│  candle_LNN/aura_lnn/src/                                          │
│  ├── api/ (Public API + Engine Worker)                             │
│  ├── llama_engine/ (LLM inference)                                 │
│  ├── memory/ (SQLite + Embeddings + RAG)                           │
│  ├── vision/ (YOLO + Emotion + Webcam)                             │
│  └── config/ (Persona + Constants)                                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        MODEL LAYER                                 │
│  aura_notebook/assets/                                             │
│  ├── LFM2.5-1.2B-Instruct-Q4_K_M.gguf (MAIN MODEL)              │
│  ├── aura-aria-gguf/LFM2.5-VL-450M.Q4_K_M.gguf (VISION MODEL)  │
│  ├── bge_model.onnx (EMBEDDER)                                    │
│  ├── yolov8n.onnx (OBJECT DETECTION)                              │
│  ├── emotion-ferplus-8.onnx (EMOTION)                             │
│  └── piper/ (TTS VOICES)                                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Chat Message

```
User types "What's my name?"
    │
    ▼
[Flutter] chat_widget.dart → aura_chat() via FRB
    │
    ▼
[Rust] api/chat/turn.rs::process_chat()
    │
    ├── classify::prepare_prompt() → detects internal/bar/vision
    │
    ├── memory::gather_memories()
    │   ├── store.get_facts_strings(10) → "User's name is Luna"
    │   ├── store.recent_turn_strings_filtered(4)
    │   └── store.search_relevant_hybrid() → cosine + BM25 RAG
    │
    ├── prefix::build_memory_prefix() → "[MEMORY: your name is Luna]"
    │
    ├── generate::run_generation()
    │   └── llama_engine.generate_with_context() → streams tokens
    │
    └── process_memory() → extracts NEW facts from conversation
        └── rules::extract_all_facts() → pattern matching
```

---

## Data Flow: Memory System

```
┌─────────────────────────────────────────────────────────────┐
│                    SQLite Database                           │
│  ~/.local/share/aura_notebook/aura_memory.db                │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  turns   │  │  facts   │  │vec_memory│  │summaries │  │
│  │(history) │  │(user info)│ │(embeddings)│ │(rolling) │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ insights │  │ triggers │  │  notes   │  │proactive │  │
│  │(patterns)│  │(bandit)  │  │(pinned)  │  │  _log    │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              Durable JSONL Mirror                            │
│  ~/.local/share/AURA/notebook.jsonl                          │
│  Survives app uninstall/reinstall via reseed_from_file()    │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Files by Purpose

### 1. CHAT PIPELINE (How messages flow)
```
candle_LNN/aura_lnn/src/
├── api/chat/turn.rs              # MAIN ORCHESTRATOR: classify → memory → generate → store
├── api/chat/turn/classify.rs     # Detects vision queries, bar/internal messages
├── api/chat/turn/memory.rs       # gather_memories() — 3-tier retrieval
├── api/chat/turn/prefix.rs       # build_memory_prefix() → [MEMORY: ...] injection
├── api/chat/turn/generate.rs     # run_generation() — multi-loop continuation
├── api/chat/output.rs            # Cleans model output, strips think blocks
└── api/chat/reply.rs             # Grounded fallback for weak responses
```

### 2. MEMORY SYSTEM (How facts are stored and retrieved)
```
candle_LNN/aura_lnn/src/
├── memory/store/core.rs          # MemoryStore::open() — SQLite schema (8 tables)
├── memory/store/facts.rs         # valid_profile_fact() — fact validation
├── memory/store/search.rs        # search_relevant_hybrid() — cosine + BM25
├── memory/store/retrieval.rs     # get_facts_strings(), recent_turn_strings()
├── memory/store/inserts.rs       # insert_turn(), insert_fact()
├── memory/store/mirror.rs        # Durable JSONL mirror for persistence
├── memory/store/bandit.rs        # Proactive trigger bandit (epsilon-greedy)
├── memory/recall.rs              # Consecutive-memory guard, dedup
└── memory/embed/model.rs         # BgeTextEmbedder — 384-dim embeddings
```

### 3. FACT EXTRACTION (How facts are extracted from messages)
```
candle_LNN/aura_lnn/src/api/worker_utils/
├── rules/mod.rs                  # Centralized extraction rules engine
├── rules/identity.rs             # name, age, gender, pronouns, occupation
├── rules/family.rs               # mom, dad, siblings, partner, friends
├── rules/pets.rs                 # cats, dogs, other animals
├── rules/preferences.rs          # likes, loves, hates, favorites
├── rules/location.rs             # city, country, origin
├── rules/goals.rs                # wants to learn, aspirations
├── rules/emotions.rs             # current mood, feelings
├── rules/events.rs               # birthday, schedule, reminders
└── rules/edge_cases.rs           # Edge case handling
```

### 4. LLM ENGINE (How inference works)
```
candle_LNN/aura_lnn/src/
├── llama_engine/model.rs         # LlamaEngine::new() — loads GGUF via llama-cpp-2
├── llama_engine/generate.rs      # generate_with_context() — main generation loop
├── llama_engine/inference.rs     # generate_stream(), generate_continue()
├── llama_engine/state.rs         # warmup() (system prompt prefill), reset_state()
└── llama_engine/embedding.rs     # load_sibling_embedder(), store_embed() worker
```

### 5. PERSONA (How ARIA's personality is defined)
```
candle_LNN/aura_lnn/
├── examples/persona_cases/system_prompt.txt     # ARIA's personality definition
├── examples/persona_cases/memory_instruction.txt # Memory recall instruction
├── examples/persona_cases/*.jsonl                # 15 persona case files
└── src/config/persona_bank.rs                    # Compile-time embedded cases
```

### 6. VISION SYSTEM (How camera/vision works)
```
candle_LNN/aura_lnn/src/vision/
├── mod.rs                        # Vision module exports
├── webcam/capture.rs             # Camera capture (V4L2/CameraX)
├── webcam/detection.rs           # YOLOv8n object detection
├── webcam/pose.rs                # YOLOv8n-pose estimation
├── webcam/emotion.rs             # Emotion detection (FER+ 8-class)
├── gate.rs                       # Confidence gate + cooldown
└── events.rs                     # Visual event storage
```

### 7. VOICE (How STT/TTS works)
```
candle_LNN/aura_lnn/src/
├── api/stt/core.rs               # Streaming STT (sherpa-onnx Zipformer)
├── api/stt/vad.rs                # Voice activity detection
├── api/tts/core.rs               # Sherpa-onnx offline TTS (Piper)
├── api/tts/online.rs             # Online TTS fallback (Google Translate)
└── api/tts/audio.rs              # Audio output device control
```

### 8. FLUTTER UI (How the app is structured)
```
aura_notebook/lib/
├── main/launch.dart              # App entry point
├── main/aura_app.dart            # MaterialApp, lifecycle
├── bar/aura_bar.dart             # Bar UI widget
├── bar/bar_controller.dart       # Bar state controller
├── bar/bar_waveform.dart         # Audio waveform animation
├── bar/bar_particles.dart        # Particle effects
├── screens/home_mode/            # Home screen
├── screens/notebook_page/        # Notebook notes
├── screens/loading_screen/       # Model download/init
├── services/bar_brain/           # Bar generation logic
├── services/tts_service/         # TTS service
└── services/stt_service/         # STT service
```

---

## File Connection Map

### `turn.rs` calls:
- `classify.rs` → prepare_prompt(), classify()
- `memory.rs` → gather_memories()
- `prefix.rs` → build_memory_prefix()
- `generate.rs` → run_generation()
- `worker_utils/memory.rs` → process_memory_with_schedule_embedding()

### `gather_memories()` calls:
- `store.get_facts_strings()` → reads from `facts` table
- `store.recent_turn_strings_filtered()` → reads from `turns` table
- `store.search_relevant_hybrid()` → reads from `vec_memory` table
- `engine.embed_query()` → uses `embed/model.rs`

### `process_memory()` calls:
- `rules/mod.rs::extract_all_facts()` → pattern matching
- `store.insert_fact()` → writes to `facts` table
- `engine.store_embed()` → writes to `vec_memory` table
- `mirror.rs::mirror_append()` → writes to JSONL

### `LlamaEngine` calls:
- `llama-cpp-2` → GGUF model loading
- `generate.rs` → token generation
- `state.rs` → KV cache management
- `embedding.rs` → BGE embedder

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `AURA_MODEL_PATH` | Path to GGUF model | LFM2.5-1.2B |
| `AURA_DB_PATH` | SQLite database path | ~/.local/share/aura_notebook/aura_memory.db |
| `AURA_CAMERA_OFF` | Disable camera | unset |
| `AURA_PROACTIVE_OFF` | Disable proactive messages | unset |
| `AURA_RAYON_THREADS` | CPU thread count | auto-detect |
| `AURA_CHAT_TEMPLATE` | Chat template | chatml |
| `AURA_NOTEBOOK_PATH` | Notebook JSONL path | ~/.local/share/AURA/notebook.jsonl |

---

## Build & Run

```bash
# Build Rust engine
cd AURA-Proj/candle_LNN/aura_lnn
cargo build --release

# Run CLI
./target/release/aura_cli

# Run single message
./target/release/sam_chat "hello"

# Run benchmarks
./target/release/bench_ttft

# Run memory eval
./target/release/memory_eval

# Build Flutter app
cd AURA-Proj/aura_notebook
flutter run -d linux
```
