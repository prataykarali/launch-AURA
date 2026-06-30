# AURA Codebase Map

Complete inventory of every section in the AURA project — Rust core, Flutter app, persona cases, and supporting infrastructure.

---

## Rust Core (`candle_LNN/aura_lnn/src/`)

### LLM Engine (`llama_engine/`)
| File | Purpose |
|---|---|
| `mod.rs` | Engine struct, embedder integration, store_embed worker |
| `model.rs` | LFM2.5-1.2B GGUF model loading, context creation |
| `generate.rs` | Token generation with system prompt + user message (NO memory injected) |
| `inference.rs` | generate_stream + generate_continue (multi-turn loop primitive) |
| `embedding.rs` | Background embedding worker (store_embed queue) |
| `state.rs` | KV cache warmup, system prompt prefill, context reset |

### Memory — Embedder (`memory/embed/`)
| File | Purpose |
|---|---|
| `model.rs` | Snowflake-arctic-embed-s ONNX embedder (384-dim, BERT arch) |
| `mod.rs` | Embedder trait, NoOpEmbedder fallback, RLScheduler |
| `plan.rs` | Reply planner — classifies prompt complexity into token budgets |
| `plan_budgets.rs` | Level/category → concrete (max_tokens, continuation) per platform |
| `scheduler.rs` | RL scheduler for proactive timing |

### Memory — Store (`memory/store/`)
| File | Purpose |
|---|---|
| `mod.rs` | MemoryStore struct, open(), pool init |
| `core.rs` | Core DB operations |
| `pool.rs` | SQLite connection pool (r2d2) |
| `facts.rs` | Facts table CRUD |
| `vec_memory.rs` | Vector memory table + sqlite-vec integration |
| `search.rs` | Hybrid cosine + BM25 semantic search over vec_memory |
| `retrieval.rs` | Facts, summaries, recent turns retrieval |
| `retrieval_utils.rs` | Token normalization, dedup helpers |
| `insights.rs` | Insights table (synthesized patterns) |
| `inserts.rs` | Insert fact, delete_name_facts, delete_facts_matching_pattern |
| `maintenance.rs` | Conversation summary rotation, auto-heal |
| `mirror.rs` | Durable JSONL mirror for cross-restart persistence |
| `notes.rs` | Memory notes (user/pinned notes, also embedded) |
| `json_export.rs` | JSON export for notebook UI |
| `notebook_paired.rs` | Paired notebook read/write |
| `notebook_ro.rs` | Read-only notebook access |
| `rows.rs` | Row type definitions |
| `utils.rs` | safe_context_memory, content filtering |
| `bandit.rs` | Multi-armed bandit for proactive trigger selection |

### Memory — Other (`memory/`)
| File | Purpose |
|---|---|
| `mod.rs` | Module exports, THINKING_SENTINEL |
| `recall.rs` | Consecutive-memory guard, dedup, cooldown (NO keyword gates) |
| `android_overlay.rs` | Android overlay config validation + JSON |
| `notebook_file/mod.rs` | Durable notebook JSONL reseed on startup |
| `notebook_file/path.rs` | Platform-specific notebook path resolution |
| `memory_health.rs` (root) | System memory pressure detection + auto-healer |

### Chat Turn Pipeline (`api/chat/`)
| File | Purpose |
|---|---|
| `turn.rs` | Main chat orchestrator: classify → gather memories → recall fast path → LLM → append memory → store |
| `turn/classify.rs` | Prompt classification (vision query, bar/internal detection) |
| `turn/generate.rs` | Bar generation (single-pass, no timeout) + full generation (multi-turn loop) |
| `turn/memory.rs` | gather_memories — pure embedder semantic RAG over vec_memory |
| `persona_retrieval.rs` | Embedder-based persona index, memory_recall matching (50 examples) |
| `output.rs` | Model output cleaning, think-block stripping, echo detection, vision query prompt |
| `reply.rs` | Grounded fallback for weak/empty responses, vision fallback |
| `mod.rs` | Module exports, aura_chat, aura_cancel, aura_prefill |

### Config (`config/`)
| File | Purpose |
|---|---|
| `persona_bank.rs` | System prompt, persona cases (JSONL loader), fallbacks, canonical classification |
| `persona.rs` | Persona config struct |
| `constants.rs` | THINKING_SENTINEL, stop tokens |
| `mod.rs` | Module exports |

### STT (`api/stt/`)
| File | Purpose |
|---|---|
| `mod.rs` | STT init, push audio, reset session |
| `core.rs` | Streaming STT core (sherpa-onnx) |
| `model.rs` | STT model loading (Paraformer int8) |
| `vad.rs` | Voice activity detection |

### TTS (`api/tts/`)
| File | Purpose |
|---|---|
| `mod.rs` | TTS init, speak, stop, set volume |
| `core.rs` | Sherpa-onnx offline TTS core |
| `model.rs` | TTS model loading (Piper en_US-lessac-medium) |
| `online.rs` | Online TTS fallback (Google Translate, configurable voices) |
| `audio.rs` | Audio output device, playback control |

### Vision (`vision/`)
| File | Purpose |
|---|---|
| `mod.rs` | Vision module exports, start_webcam_thread, get_recent_visual_context |
| `events.rs` | Visual event storage + retrieval |
| `gate.rs` | Confidence gate + cooldown for visual context injection |
| `store.rs` | Vision store integration with MemoryStore |
| `webcam/mod.rs` | Webcam module exports |
| `webcam/capture.rs` | Camera capture (V4L2 on Linux, CameraX on Android) |
| `webcam/detection.rs` | YOLOv8n object detection |
| `webcam/pose.rs` | YOLOv8n-pose estimation |
| `webcam/emotion.rs` | Emotion detection (FER+ 8-class) |
| `webcam/model.rs` | Vision model loading (YOLO + emotion ONNX) |
| `webcam/draw.rs` | Bounding box / pose overlay drawing |
| `webcam/state.rs` | Webcam state machine |
| `webcam/thread.rs` | Vision processing thread |

### Proactive (`api/memory/`)
| File | Purpose |
|---|---|
| `proactive.rs` | Proactive context, buffer status, engagement recording, overlay config |
| `notes.rs` | Memory notes API (add/delete/update/recover, exposed to Flutter) |
| `mod.rs` | Memory module exports (aura_search_relevant, health check, JSON export) |

### Engine Worker (`api/engine/`)
| File | Purpose |
|---|---|
| `init.rs` | Engine initialization: model load, embedder load (60s timeout), warmup, memory store open |
| `worker.rs` | Worker thread struct + message handling |
| `worker_loop.rs` | Main worker event loop |
| `worker_handlers.rs` | Chat/reset/inject/prefill/chunked message handlers |
| `paths.rs` | Platform-specific model/DB path resolution |
| `mod.rs` | Module exports (aura_init, aura_set_backend, etc.) |

### Worker Utils (`api/worker_utils/`)
| File | Purpose |
|---|---|
| `memory.rs` | Post-turn memory processing (schedule notes, conversation summary — NO hardcoded extractors) |
| `mod.rs` | Module exports |
| `age.rs` | Age extraction (word-boundary safe) — kept for notebook, not used in main pipeline |
| `name.rs` | Name capture — kept for notebook, not used in main pipeline |
| `preferences.rs` | Preference extraction — kept for notebook, not used in main pipeline |
| `insights.rs` | Insight synthesis — kept for notebook, not used in main pipeline |

### Other Rust (`src/`)
| File | Purpose |
|---|---|
| `api/agent.rs` | ReAct agent loop (unused, kept for reference) |
| `api/file_read.rs` | Read text files into vec_memory for RAG |
| `api/messages.rs` | EngineMsg enum (Chat, Reset, Inject, Prefill, etc.) |
| `api/config.rs` | Platform config (rayon threads, context size, performance label) |
| `api/vision.rs` | Vision API exposed to Flutter |
| `api/mod.rs` | All public API exports |
| `performance_profile.rs` | Strong/Balanced/Constrained tier detection, thread/context/batch config |
| `device_backend.rs` | CPU/GPU backend selection per platform |
| `cache/mod.rs` + `cache/disk.rs` | Disk cache for KV state |
| `frb_generated.rs` | Flutter Rust Bridge generated bindings |
| `lib.rs` | Crate root, module declarations |
| `memory_health.rs` | System memory pressure + auto-healer |

---

## Rust Binaries (`src/bin/`)

### aura_cli (`bin/aura_cli/`)
| File | Purpose |
|---|---|
| `main.rs` | Linux CLI entry point |
| `chat.rs` | Interactive chat with STT + TTS |
| `common.rs` | Shared CLI utilities |
| `stt.rs` | CLI STT test |
| `vision.rs` | CLI vision test |

### memory_test (`bin/memory_test/`)
| File | Purpose |
|---|---|
| `main.rs` | Test runner entry point |
| `runner.rs` | Test case runner (embed → generate → verify) |
| `fuzzy.rs` | Jaro-Winkler fuzzy matching |
| `report.rs` | Test report generation |
| `utils.rs` | Test utilities |

### memory_eval (`bin/memory_eval/`)
| File | Purpose |
|---|---|
| `main.rs` | Eval harness entry point |
| `eval.rs` | Evaluation logic |
| `scoring.rs` | Scoring + fuzzy matching |
| `report.rs` | Report generation |
| `text.rs` | Text processing |

---

## Persona Cases (`examples/persona_cases/`)

| File | Purpose |
|---|---|
| `system_prompt.txt` | AURA's system prompt (personality, voice, rules) |
| `memory_instruction.txt` | Memory recall instruction (kept for notebook, not fed to LLM) |
| `memory_recall.jsonl` | 50 memory-recall query examples (embedder classification) |
| `memory_recall_explicit.jsonl` | Explicit memory recall cases |
| `greetings_and_farewells.jsonl` | Greeting/farewell persona cases |
| `identity_and_who_are_you.jsonl` | Identity query cases |
| `coding_and_tasks.jsonl` | Code/task persona cases |
| `emotions_happy_celebration.jsonl` | Happy emotion support |
| `emotions_sad_support.jsonl` | Sad emotion support |
| `fallbacks.jsonl` | Timeout/weak/empty/unclear/too_long/vision fallbacks |
| `preferences_and_life.jsonl` | Preference/self-disclosure cases |
| `questions_and_facts.jsonl` | Factual Q&A cases |
| `time_and_tools.jsonl` | Time/tool cases |
| `memory_topic_linked.jsonl` | Topic-linked memory cases |
| `clean_state_banter.jsonl` | Casual banter cases |

---

## Flutter App (`aura_notebook/lib/`)

### App Entry (`main/`)
| File | Purpose |
|---|---|
| `launch.dart` | Main app launch, RustLib init, window setup |
| `aura_app.dart` | MaterialApp, lifecycle, window method handlers |
| `aura_root.dart` | Root widget: loading screen → option screen, bar startup |
| `overlay_app.dart` | Overlay entry point |
| `open_main_app.dart` | Open main window utility |

### AURA Bar (`bar/`)
| File | Purpose |
|---|---|
| `aura_bar.dart` | Bar UI widget |
| `aura_bar_app.dart` | Bar app entry |
| `bar_buttons.dart` | Mic/speaker/volume/ask buttons |
| `bar_constants.dart` | Bar dimensions, animation constants |
| `bar_controller.dart` | Bar state controller |
| `bar_root_widget.dart` | Root bar widget tree |
| `bar_shell.dart` | Bar shell layout |
| `bar_state.dart` | BarState enum (idle, listening, processing, speaking) |
| `bar_tray_icon.dart` | System tray icon |
| `bar_waveform.dart` | Audio waveform animation |
| `bar_window_manager.dart` | Window position/size management |
| `bar_multi_window_service.dart` | Desktop multi-window IPC |
| `bar_window_app.dart` | Desktop bar window app |
| `bar_particles.dart` | Particle effects |
| `aura_bar_bubbles.dart` | Proactive popup bubbles |
| `bar_contents.dart` | Bar content layout |

### Chat Widget (`screens/home_mode/chat/`)
| File | Purpose |
|---|---|
| `chat_widget.dart` | Chat widget main |
| `chat_widget/chat_widget_state.dart` | State: stream listener, streaming TTS flush, commit bubble |
| `chat_widget/chat_widget_typewriter.dart` | Typewriter effect |
| `chat_widget/chat_widget_scroll.dart` | Auto-scroll |
| `chat_message.dart` | Message model |
| `input_bar.dart` | Text input bar |
| `message_list.dart` | Message list view |
| `message_chunker.dart` | Long message chunking |
| `chat_constants.dart` | Chat UI constants |

### Screens
| Path | Purpose |
|---|---|
| `screens/home_mode/home_screen.dart` | Home mode screen |
| `screens/home_mode/widgets/` | Home widgets |
| `screens/class_mode/` | Class management: cards, tabs (quiz, attendance, assignments, doubts, overview, students), AI lesson summariser, smart briefing |
| `screens/loading_screen/` | Model download/copy, engine init, progress bar, readiness check |
| `screens/notebook_page/` | Notebook notes, dialog, actions |
| `screens/info_page/` | App info, fallback banner |
| `screens/option_screen/` | Settings/options |
| `screens/screens.dart` | Screen exports |

### Services
| Path | Purpose |
|---|---|
| `services/tts_service/` | Android platform TTS, Rust sherpa TTS, online TTS, engine, volume/mute |
| `services/stt_service/` | STT model service, whisper extension |
| `services/bar_brain/` | Bar generation logic, public API, debug, proactive triggers |
| `services/proactive_scheduler/` | Proactive trigger scheduling, debug, trigger logic |
| `services/android_overlay_service.dart` | Android overlay window management |
| `services/translation_service.dart` | Online translation |
| `services/natural_context_service.dart` | Vision/activity context sensing |
| `services/file_sense_service.dart` | File → memory service |
| `services/database_service.dart` | Flutter-side DB access |
| `services/context_buffer_service.dart` | Context buffering |
| `services/resource_guard_service.dart` | Memory pressure guard |
| `services/bounded_work_bucket.dart` | Rate-limited work queue |
| `services/stt_model_service.dart` | STT model management |

### Rust Bridge (`src/rust/`)
| Path | Purpose |
|---|---|
| `api.dart` | API barrel export |
| `api/chat.dart` | Chat API (aura_chat, aura_cancel, etc.) |
| `api/config.dart` | Config API (rayon threads, context size) |
| `api/engine.dart` | Engine API (aura_init, aura_set_backend) |
| `api/file_read.dart` | File read API |
| `api/memory.dart` | Memory API (search, health, JSON export) |
| `api/memory/notes.dart` | Memory notes API |
| `api/memory/proactive.dart` | Proactive API |
| `api/stt.dart` | STT API |
| `api/tts.dart` | TTS API |
| `api/vision.dart` | Vision API |
| `api/worker_utils.dart` | Worker utils API |
| `frb_generated.dart` | FRB generated main |
| `frb_generated.io.dart` | FRB generated IO platform |
| `frb_generated.web.dart` | FRB generated web platform |
| `lib.dart` | RustLib init |

---

## Supporting Infrastructure

### Android Build
| Path | Purpose |
|---|---|
| `candle_LNN/aura_lnn/build_android.sh` | NDK cross-compile script (aarch64-linux-android) |
| `candle_LNN/aura_lnn/patches/llama-mmap-android.patch` | llama.cpp Android NDK posix_madvise fix |
| `android/app/src/main/jniLibs/arm64-v8a/libaura_lnn.so` | Compiled Android .so |

### Mitacs (outside git repo)
| Path | Purpose |
|---|---|
| `launch-AURA/Mitacs/` | Benchmark datasets, evaluation scripts, reports |
| `launch-AURA/Mitacs/personal_memory_dataset.json` | Personal memory test dataset |
| `launch-AURA/Mitacs/memory_test_dataset.json` | Memory test dataset |
| `launch-AURA/Mitacs/generate_personal_dataset.py` | Dataset generation script |
| `launch-AURA/Mitacs/generate_charts.py` | Chart generation |
| `launch-AURA/Mitacs/failure_analysis.py` | Failure analysis script |
| `launch-AURA/Mitacs/dashboard.html` | Results dashboard |
| `launch-AURA/Mitacs/research_notes/` | Research notes |

### Explain (outside git repo)
| Path | Purpose |
|---|---|
| `launch-AURA/explain/README.md` | Architecture overview |
| `launch-AURA/explain/api_bridge/` | API bridge docs |
| `launch-AURA/explain/bar_ui/` | Bar UI docs |
| `launch-AURA/explain/llm_engine/` | LLM engine docs |
| `launch-AURA/explain/memory/` | Memory architecture docs |
| `launch-AURA/explain/stt_tts/` | STT/TTS docs |
| `launch-AURA/explain/vision/` | Vision docs |
| `launch-AURA/explain/deep_integration_and_performance.md` | Deep integration + performance |
| `launch-AURA/explain/model_and_mitacs_details.md` | Model + Mitacs details |

### Other
| Path | Purpose |
|---|---|
| `launch-AURA/MENTAL_MAP/README.md` | Project mental map |
| `launch-AURA/scripts/` | build_rust_linux.sh, inject_onnx_metadata.py, setup_voice_linux.sh |
| `candle_LNN/aura_lnn/docs/` | Dev TODO, vision_memory_plan |
| `candle_LNN/aura_lnn/Cargo.toml` | Rust crate manifest |
| `aura_notebook/pubspec.yaml` | Flutter app manifest |
| `aura_notebook/flutter_rust_bridge.yaml` | FRB config |
