# Project AURA — Comprehensive Research Summary

**A privacy-first, on-device AI companion with natural memory, voice, and vision — running entirely on mobile and desktop without cloud APIs.**

---

## 1. Project Overview

Project AURA is a fully localized AI companion that runs LLM inference, speech-to-text, text-to-speech, vision sensing, and semantic memory entirely on-device. It uses a hybrid Flutter + Rust architecture with no cloud dependency for any core function.

### Key Metrics
| Metric | Value |
|---|---|
| LLM | LFM2.5-1.2B-Instruct (Q4_K_M GGUF, 698 MB) |
| Embedder | Snowflake-arctic-embed-s (ONNX, 133 MB, 384-dim) |
| STT | Sherpa-onnx Paraformer 20M (int8) + Whisper (GPU, Linux) |
| TTS | Sherpa-onnx VITS Piper (en_US-lessac-medium) |
| Vision | YOLOv8n + YOLOv8n-pose + FER+ emotion (ONNX) |
| Memory DB | SQLite + sqlite-vec (hybrid cosine + BM25) |
| Desktop speed | ~12 tokens/s (12-thread CPU) |
| Android speed | ~4 tokens/s (6-thread CPU) |
| Warmup | 28-37s (Android), <1s (desktop cached) |

---

## 2. Architecture

### Flutter-Rust Bridge (FRB)
All heavy compute lives in Rust. Flutter handles UI, windowing, and platform channels. The bridge provides:
- Asynchronous token streaming via `StreamSink<String>`
- Background worker thread with bounded sync channel (cap 20)
- Platform-specific STT/TTS method channels (Android)

### Threading Model
```
Dart UI Thread (60fps)
    │  (non-blocking FFI)
    ▼
Rust FFI Boundary (api/mod.rs)
    │  EngineMsg → SyncChannel
    ▼
Rust Worker Thread ("aura-engine-worker")
    ├── LlamaEngine (Mutex-guarded)
    ├── MemoryStore (r2d2 SQLite pool)
    ├── STT/TTS engines
    └── Background embed worker (bounded queue, cap 8)
```

### Multi-Window System (Desktop)
- **Main Window**: Full app (chat, class mode, notebook, settings)
- **AURA Bar**: Persistent companion pill (separate window, own lifecycle)
- Closing main window hides it if bar is still open; full exit only when last window closes

### Android Overlay
- Floating bar via `flutter_overlay_window`
- Shows above other apps with system overlay permission
- Mic tap → STT → LLM → streaming TTS, all from the pill

---

## 3. LLM Engine

### Model: LFM2.5-1.2B
- **Architecture**: Recurrent Gated Delta Net (not standard Transformer)
- **Quantization**: Q4_K_M (4-bit hybrid)
- **Context**: 3072 (desktop), 2048 (Android)
- **Key constraint**: Recurrent state cannot be partially rewound — no speculative prefill

### Generation Pipeline
1. System prompt prefilled at warmup (333 tokens, cached in KV)
2. Per-turn: user prompt decoded → tokens generated → streamed to Flutter
3. **Multi-turn LOOP**: 48-token paragraphs, model continues from KV cache until EOS or 512-token ceiling
4. Context reset at 3/4 watermark (between turns, never mid-generation)

### Memory-Recall Fast Path
- 50 persona examples embedded at startup
- If query matches a memory_recall case (cosine >= 0.65) → **skip LLM entirely**
- Instant reply: "Yes, I remember you. I remember: [retrieved memory]."
- Saves 17s prompt decode on Android for recall queries

### No Persona Examples Fed to LLM
- Persona cases used for **classification only** (embedder cosine match)
- LLM sees only system prompt + user message → shorter prompt → faster decode

---

## 4. Memory System

### Design Philosophy
Memory is **never fed into the LLM**. The embedder retrieves relevant memory and **appends** it to the LLM's reply as "I remember: ...". This:
- Keeps the LLM prompt tiny (lower latency)
- Prevents the 1.2B model from hallucinating facts it can't read reliably
- Makes memory retrieval transparent (user sees what AURA remembers)

### Storage Layers
| Layer | Technology | Purpose |
|---|---|---|
| `vec_memory` | SQLite + sqlite-vec | Conversation turns + embedded content (cosine + BM25 search) |
| `facts` | SQLite table | Durable identity facts (name, age — kept for notebook) |
| `summaries` | SQLite table | Rolling 10-turn conversation summary |
| `insights` | SQLite table | Synthesized patterns (notebook Insights tab) |
| `notes` | SQLite table | User/pinned notes (also embedded into vec_memory) |
| `notebook.jsonl` | Durable file | Cross-restart mirror (reseed on startup) |

### Embedder: Snowflake-arctic-embed-s
- **Architecture**: BERT, 12 layers, 384-dim
- **Size**: 133 MB (ONNX)
- **Load time**: 1.5s (vs BGE-small which took >10s on Android → timeout → NoOp)
- **Cosine threshold**: 0.50 (lowered from 0.70 for better recall matching)

### Retrieval Flow
1. Embed user query (snowflake ONNX, ~25ms)
2. `search_relevant_hybrid`: cosine similarity + BM25 over vec_memory
3. Consecutive-memory guard (dedup, max 2 consecutive uses)
4. `format_memory_appendage`: extract user's message from turn, convert pronouns (I→you, my→your)
5. Append "I remember: you like ice cream." after LLM reply

### What Was Removed (The Hardcodes)
- `is_recall_query` + 29 keyword phrases
- `wants_broad_memory` + 25 broad markers
- `try_direct_identity_reply` + 18 "who am I" phrases
- `canonical_aura_reply` (prebuilt greetings/identity/farewell)
- `process_memory_inner` hardcoded name/age/preference/insight extractors
- Category prefill hardcodes in generate.rs (is_who_am_i, is_emotional, is_relationship, etc.)
- Memory injection into LLM context ("Facts about the User:" block + instruction)

### Pronoun Conversion
Stored turn: `"User: I like ice cream\nAURA: That sounds good!"`
→ Extracted: `"I like ice cream"`
→ Converted: `"you like ice cream"`
→ Appended: `"I remember: you like ice cream."`

### Non-Latin Script Filter
Prevents Arabic/Hindi/Cyrillic turns from being recalled into English replies (and vice versa).

### Last-Conversation Recall
- Fires once per 5-minute gap (not every turn)
- Only if previous turn was substantive (>4 words, not a greeting)
- Format: "I remember we were talking about [last topic]."
- Works in both bar and chat app

---

## 5. Reply Planner

### Complexity Classification
The planner reads the user message and assigns a `ReplyPlan` with token budgets:

| Category | Desktop | Mobile | Continuation | Examples |
|---|---|---|---|---|
| greeting | 40 | 28 | 0 | "hi", "hello" |
| acknowledgement | 60 | 40 | 0 | "my name is X" |
| factual | 120 | 80 | 0 | "what is X" |
| open_ended | 96 | 48 | 1 (loop) | "explain X", "tell me a story" |
| task_coding | 160 | 48 | 1 (loop) | "write a function" |

### Multi-Turn LOOP
- `continuation: 1` = LOOP until model emits EOS
- Each pass: 48 tokens (~1-2 sentences) from KV cache (no re-decode)
- Safety ceiling: 512 tokens (~10 paragraphs)
- Model **decides** when the answer is complete — not a fixed count

---

## 6. Voice Systems

### STT (Speech-to-Text)
| Platform | Engine | Model |
|---|---|---|
| Linux | Whisper Python server (GPU) | whisper-base multilingual |
| Android | Sherpa-onnx streaming | Paraformer 20M int8 |
| Both | VAD (voice activity detection) | Silero VAD |

### TTS (Text-to-Speech)
| Platform | Engine | Model |
|---|---|---|
| Linux | Sherpa-onnx + rodio | Piper en_US-lessac-medium |
| Android | Platform TextToSpeech | Google TTS (system) |
| Fallback | Online | Google Translate TTS |

### Streaming TTS
- **Bar**: Flushes sentence chunks during generation via `_flushPunctuationChunks` + `_flushEarlySpeech`
- **Chat app**: `_flushStreamingTts` flushes on any punctuation (comma, period, newline) with 6-char minimum threshold
- Android TTS chain removed (was causing freeze — Android has its own native queue)
- Speech starts on the first sentence, not after the full reply

---

## 7. Vision System

### Models (all ONNX, on-device)
| Model | Purpose | Size |
|---|---|---|
| YOLOv8n | Object detection (person, screen, objects) | ~6MB |
| YOLOv8n-pose | Body pose estimation | ~7MB |
| FER+ (emotion-ferplus-8) | 8-class emotion recognition | ~34MB |

### Pipeline
1. Webcam capture (V4L2 on Linux, CameraX on Android)
2. YOLO detection → objects list
3. Pose estimation → gesture recognition (wave, hand)
4. Emotion detection → mood (happy, sad, angry, etc.)
5. Vision gate (confidence + cooldown) → stored as visual event in MemoryStore
6. On vision queries ("what do you see"), visual context injected into fallback memories

### Privacy
All vision processing is on-device. No frames leave the device. Camera is off by default and only activates in "watch mode" or when a vision query is detected.

---

## 8. Proactive System

### Proactive Scheduler
- Timer-based (720s default interval on desktop)
- Multi-armed bandit (`bandit.rs`) selects trigger type based on engagement history
- Triggers: vision event, speech detected, app context change
- Proactive popups capped at 220 chars, 7s display on Android
- Proactive responses are stored as notebook notes

### Resource Guard
- Monitors system memory pressure
- On critical pressure: cancels proactive triggers, lowers performance profile
- Auto-healer (`memory_health.rs`) runs SQLite VACUUM + clears old vec_memory rows

---

## 9. Performance Profiling

### Tiers
| Tier | Threads | Context | Batch | Continuation | Target |
|---|---|---|---|---|---|
| Strong | 4-8 | 3072 | 512 | yes | Desktop (12+ cores) |
| Balanced | 4-6 | 2048 | 256 | yes | Mobile (6 cores) |
| Constrained | 1-2 | 1536 | 128 | no | Low-end (1-2 cores) |

### Auto-Fallback
- Monitors tokens/s after each generation
- 2 consecutive slow generations → smooth fallback to lower tier
- Slow thresholds: Strong <9 tok/s, Balanced <6 tok/s, Constrained <3.5 tok/s

### Measured Performance
| Metric | Desktop (12-thread) | Android (6-thread) |
|---|---|---|
| Warmup | 0.8s (cached) / 4.7s (cold) | 28-37s |
| Prompt decode (45 tokens) | 0.85s | 4-8s |
| Generation speed | 12 tok/s | 3-5 tok/s |
| Embedder load | 0.2s | 1.5s |
| Query embedding | 25ms | 35ms |
| Semantic search | 0.3ms | 0.3ms |
| Total chat turn | 3-5s | 15-30s |

---

## 10. Flutter App

### Screens
| Screen | Purpose |
|---|---|
| Loading | Model download/copy, engine init, progress bar |
| Home | Chat interface with streaming + TTS |
| Class Mode | Class management (cards, tabs, AI quiz, attendance, assignments, doubts, smart briefing) |
| Notebook | Notes, insights, proactive log, memory browser |
| Options | Settings, volume, mute, model info |
| Info | About, dependencies, fallback banner |

### AURA Bar
- Persistent floating companion (desktop multi-window / Android overlay)
- States: idle → listening → processing → speaking → proactive
- Mic tap → STT → LLM → streaming TTS
- Text submit → LLM → streaming TTS
- Speaker tap → re-speak last response
- Volume tap → mute/unmute
- Proactive popups → auto-triggered based on context

---

## 11. Mitacs Research

### Evaluation Datasets
- `personal_memory_dataset.json`: 1000 test cases across 10 categories
  - Identity, preferences, relationship graphs, temporal events, corrections
  - Multi-fact synthesis, emotional context, long-context recall
- `memory_vision_dataset.json`: Vision + memory cross-modal cases

### Evaluation Harness
- `memory_test/`: Rust binary — embed → generate → fuzzy keyword verify (Jaro-Winkler)
- `memory_eval/`: Rust binary — dataset-driven eval with scoring + report
- `failure_analysis.py`: Python — extracts failure modes from eval output
- `generate_charts.py`: SVG charts (category accuracy, difficulty accuracy)
- `dashboard.html`: Interactive results dashboard

### Benchmark Results
| Benchmark | Result |
|---|---|
| HashMap vs SQLite fact lookup | 0.25µs vs 6.8µs (28x speedup) |
| Ring Buffer (audio PCM) | 1 ns/op |
| KV Cache hit vs miss TTFT | 39ms vs 1041ms (26.6x) |
| Average inference (LFM-230M) | 72.3 tokens/s |
| Embedder query latency | 25ms (snowflake 384-dim) |

---

## 12. Platform Differences

| Feature | Linux | Android |
|---|---|---|
| LLM context | 3072 | 2048 |
| Threads | 8 | 6 |
| STT | Whisper GPU | Sherpa-onnx int8 |
| TTS | Sherpa-onnx Piper | Platform Google TTS |
| Vision | V4L2 webcam | CameraX |
| Window | desktop_multi_window | flutter_overlay_window |
| Model delivery | Bundled in assets | Downloaded/pushed to app_flutter |
| Embedder | BGE-small (local) | Snowflake-arctic-embed-s (pushed) |
| Warmup | <1s (cached) | 28-37s |
| Bar timeout | None (Flutter 16s) | None (Flutter 90s first, 40s inter-token) |

---

## 13. File Layout

```
launch-AURA/
├── AURA-Proj/                    # Git repo (github.com/prataykarali/launch-AURA)
│   ├── candle_LNN/aura_lnn/      # Rust core (LLM + memory + voice + vision)
│   │   ├── src/                  # Rust source
│   │   ├── examples/persona_cases/  # Persona JSONL + system prompt
│   │   ├── build_android.sh      # Android NDK cross-compile
│   │   └── Cargo.toml
│   ├── aura_notebook/            # Flutter app
│   │   ├── lib/                  # Dart source
│   │   ├── assets/               # TTS voice, ONNX models
│   │   ├── android/              # Android jniLibs + Kotlin
│   │   ├── linux_libs/           # Linux .so
│   │   └── pubspec.yaml
│   ├── android/                  # Root Android jniLibs
│   ├── lib/                      # Root Flutter lib
│   ├── assets/                   # Root assets (embedder, tokenizer)
│   └── CODEBASE_MAP.md           # Full codebase section map
├── Mitacs/                       # Research sandbox (datasets, eval, charts)
├── explain/                      # Architecture docs (api_bridge, bar_ui, llm_engine, memory, stt_tts, vision)
├── MENTAL_MAP/                   # Project mental map
└── scripts/                      # Build + setup scripts
```

---

## 14. Key Design Decisions

1. **Memory never fed to LLM** — appended after generation. The 1.2B model hallucinates facts from context; appending is reliable and lower-latency.

2. **Snowflake embedder over BGE** — BGE-small took >10s to load on Android (ONNX Runtime hang), falling back to NoOp (zero vectors → no memory). Snowflake loads in 1.5s.

3. **Multi-turn LOOP, not fixed count** — the model decides when an answer is complete (EOS). Fixed counts either cut off mid-sentence or wasted passes.

4. **Memory-recall fast path** — "who am I" / "do you remember me" skip the 17s LLM decode entirely. The embedder matches the query to a recall case and replies from memory instantly.

5. **No prebuilt greetings** — removed `canonical_aura_reply` which bypassed the LLM with hardcoded responses. Everything goes through the model now.

6. **Streaming TTS** — speech starts on the first sentence, not after the full reply. Reduces perceived latency from 15s to ~3s on Android.

7. **Persona examples for classification, not generation** — the 50 memory_recall examples are matched by embedder cosine to trigger the fast path. They're NOT fed into the LLM context (was causing 83-token prompts → 17s decode → timeouts).
