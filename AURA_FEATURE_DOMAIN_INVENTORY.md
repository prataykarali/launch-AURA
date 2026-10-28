# AURA — Full Feature & Domain Inventory

**Last updated:** 2026-07-24

**What AURA is:** an on-device AI companion (**ARIA** persona) built as **Flutter UI + Rust engine** (`candle_LNN` / `aura_lnn`) over **Flutter-Rust Bridge**. Primary target is **Linux desktop**; **Android** is in progress. Main model: **LFM2.5-1.2B** (GGUF).

Status is drawn from `FEATURE_STATUS.md` (July 10, 2026), codebase maps, platform diagnostics, and QA sessions (Sam/Billie/Kuldeep/Taylor).

**Important:** “code exists / marked working” ≠ “always reliable in real use.”

---

## Architecture domains (the stack)

| Layer | Location | Role |
|--------|----------|------|
| Flutter UI | `AURA-Proj/aura_notebook/lib/` | Windows, bar, chat, class mode, services |
| FRB bridge | `lib/src/rust/api/` ↔ `candle_LNN/.../api/` | Chat, memory, STT/TTS, vision, engine |
| Rust engine | `candle_LNN/aura_lnn/src/` | LLM, memory/RAG, voice, vision, proactive |
| Models/assets | `aura_notebook/assets/`, `models/` | GGUF LLM, ONNX embedder/YOLO/emotion, Piper TTS |
| Research/eval | `Mitacs/`, `Mitacs-Reports/`, `scripts/` | Benchmarks, SFT data, QA harnesses |

---

## 1. Core chat / LLM engine

**Domain:** local inference + streaming chat.

| Feature | Status | Notes |
|---------|--------|--------|
| GGUF load (LFM2.5-1.2B) | **Works** | Ship model; 450M Aria weaker on persona |
| Streaming tokens → Flutter | **Works** | Typewriter + catch-up in chat UI |
| Multi-loop long replies | **Works** | Continues until budget / natural stop |
| System prompt (ARIA) | **Works** | Compile-time persona bank |
| Cancel mid-generation | **Works** | `aura_cancel` |
| KV warmup / TTFT | **Works** | ~34–55ms TTFT in some benches |
| Performance tiers | **Works** | Strong / Balanced / Constrained |
| ReAct agent loop | **Exists, unused** | `api/agent.rs` reference only |
| Quality on hard prompts | **Weak** | Open-ended / long reasoning often nonsense or cut off |
| CPU speed / RAM | **Painful** | ~0.7 tok/s, ~8GB on 1.2B (CPU); small model faster but worse persona |

**QA reality:** bar chat is usable, but messages can drop while generating/TTS; multi-turn length can collapse; dynamic length control is imperfect.

---

## 2. Memory system (core differentiator)

**Domain:** remember user facts + inject them into prompts.

### What exists

| Piece | Status |
|-------|--------|
| SQLite 8 tables (turns, facts, vec_memory, summaries, insights, triggers, notes, proactive_log) | **Implemented** |
| Fact extraction (8 categories: identity, family, pets, prefs, location, goals, emotions, events) | **Works (rules engine)** |
| Prefix injection `[MEMORY: ...]` | **Works** |
| 3-tier retrieval (facts → recent turns → hybrid RAG) | **Works** |
| Hybrid search (cosine + BM25 + recency) | **Works** |
| Snowflake/BGE-style embedder (384-d ONNX) | **Works** |
| Durable JSONL mirror (survives reinstall) | **Works** |
| Question-as-fact guard, validation, correction (“actually…”) | **Works** |
| Consecutive-memory guard / dedup | **Works** |
| Memory wipe | **Works** |
| Persistence across restarts | **Works (strong)** |

### Gaps / bugs

| Issue | Severity |
|-------|----------|
| Specific recall fails (e.g. cat “Mochi”, “loves ramen”) | Critical quality |
| Idioms stored as facts (“explain like I’m 5” → age=5) | Medium |
| Multi-fact sentences often only keep first fact | Medium |
| Past location stored as current (“used to live in Tokyo”) | Medium |
| Memory dumps instead of natural answers | Medium |
| Long-term consolidation, decay, sync, user memory editor | **Not started** |
| Multi-fact pre-fill / char budget / BM25 tuning | **WIP** |

---

## 3. ARIA persona

| Feature | Status |
|---------|--------|
| Teenage-girl persona, short warm replies | **Mostly works** |
| “Never say I’m an AI” rules | **Mostly works** |
| ~15 persona case JSONL banks | **Embedded** |
| Persona score (1.2B) | ~**5/10** in internal evals |
| 450M Aria identity confusion (“I’m Luna”) | **Broken / do not ship** |
| Multi-persona / evolution / marketplace | **Future** |

---

## 4. AURA Bar (companion UI)

**Domain:** always-on floating pill + state machine.

| Feature | Status | Platform |
|---------|--------|----------|
| Floating pill, states (idle/listening/processing/speaking/proactive) | **Works** | Linux strong |
| Waveform + particles | **Works** | |
| Proactive bubbles | **Works (UI)** | Content quality varies |
| Tray icon | **Works** | Linux |
| Independent window lifecycle (hide main, keep bar) | **Works** | Linux |
| Cross-window IPC | **Works** | Linux |
| Bar input after relaunch | **Broken (Linux QA)** | Keyboard/IME death |
| Input while generating/TTS | **Broken** | Silent drop / block |
| Android overlay bar | **Partial / buggy** | See Android section |

---

## 5. Voice (STT / TTS)

| Feature | Claimed | Real status |
|---------|---------|-------------|
| Rust STT (sherpa Zipformer) | Implemented | **Linux often bypassed** → Whisper path; dead Linux sherpa init block |
| VAD | Implemented | Depends on path |
| Local TTS (Piper via sherpa) | Implemented | **Linux often fails** if ONNX missing `sample_rate` metadata → silent / online / fake timer |
| Streaming TTS (speak while generating) | Implemented | Ordering/blocking issues |
| Online TTS fallback | Implemented | Needs network |
| Android STT/TTS | Partial | Mic FGS type, choppy platform TTS |
| Multi-language / voice clone / emotion TTS | Future | |

**Linux voice issues (documented):** ALSA double-`arecord` EBUSY, Whisper zombie processes, 8–15s Whisper cold start, silent `_simulateSpeech` fallback.

---

## 6. Vision

| Feature | Status |
|---------|--------|
| Webcam capture (V4L2 / CameraX) | **Works** (when camera on) |
| YOLOv8n objects | **Works** |
| YOLOv8n pose / gestures | **Works** (basic) |
| FER+ emotion | **Works** |
| Vision gate + cooldown + event store | **Works** |
| Screen capture / activity from window title (Linux) | **Partial** (scrot + heuristics) |
| **Screen OCR / “what’s on my screen?”** | **Does not work** — biggest product gap in QA |
| MediaPipe / real hands / CLIP visual RAG / captioning / video memory | **WIP or future** |

Camera vision is real; **desktop/screen understanding is not**.

---

## 7. Proactive system

| Feature | Status |
|---------|--------|
| Scheduler + bandit triggers in DB | **Fires** |
| Clock / idle / schedule-note checks | **Implemented** |
| Overlay bubbles | **UI works** |
| Engagement recording | **Implemented** |
| Model-written natural nudges | **WIP** (often canned / context-contaminated) |
| Real timers for “remind me in 2 min” | **Does not work** — LLM acknowledges, no timer subsystem |
| Context-aware timing (busy/screen/speech) | **Partial / WIP** |

---

## 8. Flutter product surfaces (screens)

### Home mode

- Chat UI, streaming, typewriter, input bar → **works** (engine-dependent)
- Home widgets / links → present

### Notebook

- Notes UI + Rust notes API → **implemented**
- Stats / tabs → **UI present**

### Loading / options / settings / info

- Model download/copy, readiness, option “worlds” (AURA vs Class) → **works as app shell**

### Class mode (large domain — education UI)

| Area | Status |
|------|--------|
| Class list CRUD (`aura_classes.db`) | **Works** (local SQLite) |
| Class cards, detail shell, tabs UI | **Built** |
| AI quiz (streams `auraChat`, parses MCQ) | **Wired to LLM** |
| Doubt queue AI answers | **Wired to LLM** |
| Lesson summariser | **Wired to LLM** |
| Subject overlay chat | **Wired to LLM** |
| Attendance, assignments, students, leaderboard, resources, stream, overview topics | **Mostly UI / local models** — not a full backend LMS |
| Smart briefing card | **UI + some state** |

Class mode is a **product surface with selective LLM hooks**, not a complete school backend.

---

## 9. Supporting services (Flutter)

| Service | Role | Status |
|---------|------|--------|
| `bar_brain` | Orchestrates bar: mic, gen, proactive, vision, wake | **Core path works**, edge cases flaky |
| `proactive_scheduler` | Triggers | **Runs**; content quality uneven |
| `natural_context_service` | Activity / stuck-screen style signals | **Partial** |
| `file_sense_service` | File → memory | **Exists** |
| `translation_service` | Online translate + Indic transliteration maps | **Exists** |
| `resource_guard` / `bounded_work_bucket` | Load protection | **Exists** |
| `android_overlay_service` | Floating bar on Android | **Broken-ish** (see below) |

---

## 10. Platform matrix

| Platform | Overall | Notes |
|----------|---------|--------|
| **Linux desktop** | **Primary / most complete** | Bar multi-window, chat, memory strong; voice + screen vision weak |
| **Android** | **Partial** | Overlay: mic FGS type, resize `\|\|` bug, full-width touch steal, keyboard `FLAG_NOT_FOCUSABLE`, OEM kills service |
| **macOS / iOS / Windows / Web** | **Scaffold only / future** | Flutter folders exist; not product-ready |
| **CLI tools** | **Useful for eval** | `aura_cli`, `memory_eval`, `memory_test`, `sam_chat` |

### Android overlay known issues

1. **Background mic blocked** — OverlayService starts foreground with media-playback only, missing microphone type (Android 14+).
2. **Dynamic resize bug** — `||` instead of `&&` in height check causes invalid dimensions.
3. **Touch interception** — Full-width overlay steals taps beside the pill.
4. **Keyboard focus** — `FLAG_NOT_FOCUSABLE` blocks soft keyboard for text input.
5. **OEM battery kills** — Service can vanish unless battery unrestricted.

---

## 11. Training / Mitacs / research (not runtime product)

| Domain | What exists |
|--------|-------------|
| SFT datasets | `training_data/*`, `aura_sft_*.jsonl`, gen scripts |
| Model research | LFM vs Llama/Qwen benches, personal-memory evals |
| QA harnesses | Sam Altman 3hr, Billie/Kuldeep/Taylor trackers |
| Fine-tune pipeline as product loop | **Future** (scripts exist; not closed-loop RLHF) |

---

## Scoreboard: what works vs what doesn’t

### Solid / protect these

1. Local LLM chat + streaming
2. Memory DB + prefix RAG + restart persistence + wipe
3. ARIA short-form personality (1.2B)
4. Linux multi-window bar lifecycle
5. Camera YOLO/pose/emotion pipeline
6. Class list persistence + some AI class tools

### Partial / flaky

1. Voice (especially Linux offline TTS/STT path)
2. Proactive content quality
3. Android overlay + mobile voice
4. Fact extraction edge cases
5. Response length / multi-turn quality
6. Class mode beyond CRUD + a few LLM tabs

### Broken or missing for “real product”

1. **Screen reading / OCR** (“what’s on my screen?”)
2. **True reminders / scheduling**
3. **Bar input reliability** (relaunch, during TTS, message queue)
4. **Reliable offline Linux TTS** without metadata/setup fixes
5. **High-quality long-form reasoning** on 1.2B CPU
6. Cross-device memory, multi-persona, calendar/email/smart-home/web search

### Future (documented, not started)

Long-term memory decay/consolidation, CLIP visual RAG, multi-language voice, iOS/web, persona marketplace, full integrations.

---

## How the domains connect (one flow)

```
User (Bar / Chat / Class)
    → Flutter services (bar_brain, STT/TTS, vision)
    → FRB
    → Rust: classify → gather memory → [MEMORY:] prefix → generate stream
    → store turn + extract facts + embed for RAG
    → optional proactive bandit / vision events
```

---

## Bottom line

AURA today is a **real local companion stack**: **chat + memory + bar + camera vision + education UI shell**, strongest on **Linux**.

It is **not** yet a reliable always-on assistant for: **screen awareness, reminders, polished voice, Android overlay, or strong open-ended intelligence**. Memory is the best differentiator and still has **specific recall + extraction bugs**.

---

## Related docs

| Doc | Purpose |
|-----|---------|
| `FEATURE_STATUS.md` | Checklist of working / WIP / future |
| `AURA-Proj/CODEBASE_MAP.md` | File-level inventory |
| `AURA_PROJECT_SUMMARY.md` | Architecture summary |
| `AURA_PROJECT_ROADMAP.md` | Data flows and key files |
| `Project-Guide/README.md` | Reading order for the codebase |
| `explain/README.md` | Subsystem mindmap |
| `android_aura_bar_issues.md` | Android overlay diagnostics |
| `AURA-Proj/linux_voice_issues.md` | Linux STT/TTS diagnostics |
| `final_report.md` | Sam Altman QA session summary |
| `Mitacs-Reports/` | Benchmarks and test reports |
