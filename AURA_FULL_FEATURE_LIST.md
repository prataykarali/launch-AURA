# AURA — Complete Feature List by Status

Every product surface, engine capability, research artifact, and known gap.
Status is **real-use status**, not “file exists.”

---

## Status legend

| Tag | Meaning |
|-----|---------|
| **STRONG** | Implemented, verified, the thing you can demo without sweating |
| **DONE** | Implemented and generally works |
| **PARTIAL** | Code exists, quality or coverage is uneven |
| **RISKY** | Works on a happy path, breaks under real use |
| **BROKEN** | Claimed or coded, fails the thing it is supposed to do |
| **WIP** | Started, not finished |
| **FUTURE** | Documented, not started |
| **RESEARCH** | Eval / training / paper material, not a shipped product feature |

---

## 1. STRONG — protect these, demo these

These are AURA’s actual strengths. This is what a paper or internship reviewer should see first.

### Local companion chat
- On-device LLM inference (no cloud required for core chat)
- Ship model: **LFM2.5-1.2B Instruct GGUF Q4_K_M** via `llama.cpp` (`llama_cpp_2`)
- Flutter ↔ Rust via Flutter-Rust Bridge (streaming tokens)
- Streaming typewriter UI with catch-up so Dart stays synced with Rust tokens
- Cancel / interrupt generation mid-stream
- ChatML template + ARIA system prompt injection
- Multi-loop continuation for long replies (re-inject own output until budget / sentence stop)
- Reply planner (vibe / complexity levels 0–6 → token budgets + continuation count)
- KV-cache warmup (system prompt prefill) → TTFT ~34–55 ms in benches
- Performance tiers: Strong / Balanced / Constrained (threads + context)
- Context reset at ~¾ window so LFM linear `n_past` latency does not explode
- Sampler: temp 0.8, top-k 40, top-p 0.85, repeat penalty 1.1 / last-64
- Deferred fact extraction (learn after first token starts) so TTFT stays low

### Persistent memory (the differentiator)
- SQLite WAL store, 8 tables: `turns`, `facts`, `vec_memory`, `summaries`, `insights`, `triggers`, `notes`, `proactive_log`
- 3-tier retrieval: structured facts → recent turns → hybrid RAG
- Hybrid search: cosine + BM25 + recency boost
- Dedicated 384-d embedder (BGE-small / Snowflake-style ONNX), **not** the chat model
- Background embed worker (chat thread never waits on embedding)
- Prefix injection: `[MEMORY: …]` into the prompt
- Rule-based fact extraction (8 categories): identity, family, pets, preferences, location, goals, emotions, events
- Fact validation (`valid_profile_fact`, 80+ allowed prefixes)
- Question-as-fact guard (does not store questions as facts)
- Correction detection (“actually…”, “just kidding” deletes / updates)
- Consecutive-memory guard / dedup (stops parroting the same fact)
- Durable JSONL mirror (`~/.local/share/…/notebook.jsonl`) survives uninstall/reseed
- Memory wipe / reset
- Persistence across app restarts
- Summarization triggers: session end, topic shift, mechanical cap (~every 6 exchanges)
- Insights table (synthesized patterns with confidence / evidence)
- Memory eval harnesses + personal-memory datasets + Mitacs numbers

### ARIA persona (good enough to demo)
- Named companion persona (ARIA): warm, short, teenage-girl energy
- “Never say I am an AI / language model” rules
- ~15 compile-time persona case banks (greetings, identity, emotion, recall, …)
- Bar uses `[BRIEF]` so replies stay 1–3 sentences
- Grounded fallback path for weak / empty model replies

### AURA Bar on Linux (the face of the product)
- Persistent floating companion pill
- States: idle, listening, processing, speaking, proactive, learning
- Waveform visualization
- Particle / idle “closed mouth” animation
- Proactive message bubbles
- Tray icon
- Independent window lifecycle (close/hide main, bar stays, engine stays alive)
- Cross-window IPC (`aura/bar-to-main`, `aura/main-to-bar`, `aura/bar-to-bar`)
- Volume up / down / mute
- Push-to-talk mic
- Typewriter + bubble overlays (ask-anything, listening, processing, wake, watching, warning, learning)

### Camera vision (webcam path)
- Linux V4L2 + Android CameraX capture
- YOLOv8n object detection
- YOLOv8n-pose
- FER+ 8-class emotion
- Vision gate (confidence + per-label cooldown)
- Visual events stored as `vision:` facts
- Live debug draw (bounding boxes) exists in the Rust webcam loop

### Linux product shell
- Loading screen: model download / copy / readiness / error card
- Option screen: AURA world vs Class world
- Home chat
- Notebook page (turns / facts / summaries / notes tabs)
- Settings (at least online-translation toggle)
- Info page
- Multi-window hide strategy: full `exit(0)` only when last window closes

### Research / eval (already have numbers)
- Model bake-off: LFM2.5-1.2B vs 230M vs Llama-3.2-1B vs Qwen2.5-0.5B/1.5B vs Aria-450M
- Personal-memory prefix evals + 30/50-case + hard-case logs
- Memory test / `memory_eval` / `bench_ttft` / integration_test binaries
- Sam / Billie / Kuldeep / Taylor QA sessions + failure analyses
- SFT datasets (chat, memory, nomemory, vision, proactive, command-intent)
- Thesis outline + evaluation framework drafts

---

## 2. DONE — implemented, generally works

### Chat / engine plumbing
- Engine worker thread + message channel (`EngineMsg`)
- Classify turn: internal / bar / vision / normal
- Output cleaner (strip think-blocks, junk)
- Amnesia guard (do not inject “I don’t remember” style denials as memory)
- CLI: `aura_cli`, `sam_chat`, `model_smoke`
- File-read into memory API (`aura_read_file_into_memory`)
- Plugin registry hook (pre-LLM `can_handle` / `handle`, post-process)

### Memory extras
- User-pinned notes (notebook + `vec_memory` mirror)
- Notebook UI: tabs, stat chips, empty states, note CRUD dialogs
- JSON export path on the store
- Connection pool + busy timeout
- Topic-drift helper (`compute_drift` from vec centroid)

### Bar extras
- 2s max-listen cap + silence finalize
- Last-writer-wins queued prompt
- 30s stale-processing lock reclaim
- Scrolling / paraphrase hook (`handleScrollingInteraction`)
- Overlay bubbles for each bar state

### Voice (the pieces that exist)
- Rust STT: sherpa-onnx Zipformer 20M int8 (feature-gated)
- VAD / endpoint rules (2s silence, 1.2s breath, 20s max)
- Rust TTS: sherpa Piper VITS (`en_US-lessac-medium` / amy-low) + rodio
- Streaming TTS (speak sentence while generating)
- Online TTS fallback (Google Translate TTS)
- Android / iOS platform STT (`speech_to_text`)
- Android platform TTS MethodChannel
- Linux Whisper Python server fallback
- `arecord` capture path on Linux
- Sound-level stream for waveform
- STT model download service

### Vision extras
- Motion / wave heuristic on frame difference
- Visual context query (`get_recent_visual_context`)
- Flutter vision service: capture, pipeline, motion, profiles
- VLM loader exists (LFM2.5-VL 450M / 1.6B + mmproj) for image-conditioned generate

### Flutter services that exist and run
- `bar_brain` orchestrator (mic, gen, proactive, vision, volume, greeting)
- `proactive_scheduler` (clock / idle / bandit)
- `resource_guard` + `bounded_work_bucket` (don’t melt the CPU)
- `preferences_service`
- `database_service` (class-mode local SQLite)
- `character_bus` (UI character / Rive hook)
- `context_buffer_service`
- `plugin_registry` (Dart side)
- Path manager + responsive helpers

### Class mode (education world) — local product surface
- Class list CRUD (`aura_classes.db`)
- Class cards, colors, options sheet, add-class sheet
- Class detail shell + tabs
- Overview topics / levels / metrics
- Attendance tab (local)
- Assignment tracker (local models)
- Students roster / CR panel / catch-up view
- Leaderboard UI
- Resources tab
- Stream tab
- Lessons tab
- Smart briefing card
- AI quiz (streams `auraChat`, parses MCQ, results screen)
- Doubt queue (LLM-answered cards)
- Lesson summariser (LLM)
- Subject overlay chat (LLM)
- Class-mode AI overlay / floating buttons / banner / stats row

### Loading / onboarding
- Desktop / Android / iOS loading branches
- Download progress bar
- Readiness checks
- Fallback / error card
- Animation sequence

### Translation
- Offline Indic transliteration maps (north + south)
- Online translation **opt-in** (privacy: offline first, settings toggle)
- Command `/…` bypass
- Translation privacy test exists

### Research tooling (usable, not the product)
- Ablation runner
- Dataset builders / SFT generators / Unsloth train script
- Sam Altman 3-hour / bar-live / orchestrator scripts
- YOLO / perception test scripts
- Chart + dashboard HTML for benches

---

## 3. PARTIAL — exists, quality is uneven

### Persona / generation quality
- Persona score ~**5/10** on 1.2B (usable, not charming every turn)
- Open-ended / long reasoning often thin, cut off, or vague
- Dynamic length control imperfect (poems / lists get truncated)
- Memory sometimes dumped as a list instead of a natural answer
- Multi-turn conversation can collapse in length or lose thread
- 450M Aria: faster, **persona identity broken** (says it is the user)

### Memory quality
- Many facts extract correctly; **specific recall still fails** (cat name, “what do I love?”)
- Multi-fact sentences often keep only the first fact
- Idioms can become facts (“explain like I’m 5” → age 5)
- Past tense stored as present (“used to live in Tokyo”)
- Multi-fact pre-fill / 2000-char budget / BM25 knobs: coded-ish, not finished
- Insights exist but are not a polished “I noticed you…” product

### Proactive companion
- Scheduler runs; bandit table + engagement recording exist
- Clock / idle / schedule-note checks fire
- Overlay bubbles show
- **Content** is often canned, contaminated by memory, or not actually helpful
- Model-written English nudges: WIP
- Context-aware timing (busy screen / speech / camera): partial

### Voice
- Paths exist for Rust / Whisper / platform
- Linux often **bypasses** sherpa STT → Whisper (8–15 s cold start)
- Linux Piper TTS often **fails** ONNX `sample_rate` probe → online or silent fake timer
- Streaming TTS ordering / blocking issues
- Android STT/TTS: permissions + choppy platform voice
- Wake-word loop exists in `bar_brain` but **flagged off** (push-to-talk only)

### Vision beyond webcam objects
- Camera YOLO/pose/emotion: real
- Screen activity heuristics / `scrot` / window title: partial
- Screen OCR plugin (tesseract, trigger phrases): **coded**, not reliable product
- Visual context injection into chat: partial / can pollute identity facts (same `facts` table)
- VLM weights exist; not a clean “look at this image” product loop
- CLIP visual RAG / captioning / video memory: not there

### Bar UX
- Beautiful on Linux when idle/speaking
- Input after relaunch: flaky
- Input while generating / TTS: silent drop
- Android overlay bar: see RISKY

### Class mode
- Looks like an LMS
- Persistence is **local SQLite**, not a real school backend
- AI tabs are wired; attendance / assignments / students / leaderboard are mostly UI + local state

### File sense
- Linux file picker (zenity / kdialog / yad) + Rust ingest
- Not a general “understand my files” product
- Non-Linux pickers: null

### Platforms
- **Linux desktop**: primary, most complete
- **Android**: app + overlay exist, not trustworthy
- **Windows / macOS / iOS / Web**: Flutter folders / stubs, not product

---

## 4. RISKY — do not demo these without a script

| Feature | Why it is risky |
|---------|-----------------|
| Linux offline voice as “fully local” | Sherpa init often false; Whisper / online / silent fallback |
| “AURA can see your screen” | Camera ≠ screen. OCR plugin needs tesseract + triggers; QA said this is the biggest product hole |
| “Remind me in 2 minutes” | LLM agrees. No real timer subsystem. Does not fire |
| Android floating bar | Mic FGS type missing (Android 14+), resize `\|\|` bug, full-width touch steal, `FLAG_NOT_FOCUSABLE`, OEM battery kill |
| 450M Aria as the face | Identity confusion (“I’m Luna”) |
| Long-form intelligence | 1.2B CPU ~0.7 tok/s, ~8 GB RAM, ~19 s/reply; quality 5/10 |
| Bar input during speech | Messages drop |
| Wake word | Code present, disabled; enabling fights mic/TTS locks |
| Dual `arecord` (WAV + level meter) | ALSA EBUSY without Pulse/PipeWire mixing |
| Whisper fallback | Zombie Python processes, VRAM leak on crash |
| Vision facts in identity slot | `vision:` rows sit in `facts` and get always-injected |
| Plugin screen-OCR + resource guard | User-initiated capture path is new; not battle-tested |
| Class-mode as “education product” | Shell + a few LLM hooks, not a complete system |
| ReAct agent loop (`api/agent.rs`) | Exists, unused |
| Web / iOS / Windows “support” | Scaffold only |

---

## 5. BROKEN — coded or claimed, fails the job

- **Screen reading / “what’s on my screen?”** as a reliable product feature
- **True reminders / alarms / “remind me in N minutes”**
- **450M Aria identity** (confuses user name with persona)
- **Specific fact recall** in the cases QA named (Mochi the cat, loves ramen) — facts are in the DB, model still misses
- **Android background mic** on overlay (media-playback FGS, no microphone type)
- **Android overlay resize** (wrong boolean in height check)
- **Android overlay click-through** (invisible full-width blocker)
- **Android overlay keyboard** (`FLAG_NOT_FOCUSABLE`)
- **Linux sherpa STT as default path** (early return / bypass)
- **Linux Piper TTS without metadata patch** (`sample_rate` probe)
- **Bar keyboard after Linux relaunch** (IME death in QA)
- **Cross-device memory sync**
- **User-facing memory editor** (notebook shows facts; not a real editor / decay / export product)

---

## 6. WIP — started, not finished

### Memory
- Multi-fact pre-fill (“Here’s what I know about you:”)
- Char-budget cap on injected facts (~2000)
- BM25 parameter tuning (K1, B, scale)

### Vision
- MediaPipe ObjectDetector (TFLite ~2 MB)
- Real hand / pose landmarks (not YOLO-n heuristic)
- Real face / expression model (beyond FER+)
- CLIP image embeddings / visual RAG
- Visual context injection (max 3 lines per query)
- Screen OCR as a first-class, always-on path

### Voice
- Android STT reliability (permission + recognizer)
- Android TTS smoothness
- Visible diagnostics for “which TTS/STT/translation source am I using?”

### Android bar
- Overlay routing for proactive update/speak
- Compact-state click blocker
- Keyboard focus flags

### Proactive
- Model-written nudges (no canned lines)
- Timing that respects screen / camera / speech / typing
- Gesture → response routing

### Training loop
- SFT scripts exist; closed-loop DPO / RLHF / distillation not a product

---

## 7. FUTURE — not started (do not claim)

### Memory
- Long-term consolidation of old turns (beyond current mechanical summarize)
- Memory decay / forgetting
- Cross-device sync
- Memory export/import as a user feature
- Full user-facing memory editor

### Vision
- Scene understanding
- Image captioning as a product
- Video memory (record + recall visual events)
- AR overlay annotations

### Voice
- Multi-language beyond English
- Voice cloning / custom ARIA voice
- Emotion-aware TTS
- Local Whisper replacing the Python server

### Persona
- User-selectable multiple personas
- Persona evolution from interaction
- Custom persona creator
- Persona marketplace

### Integrations
- Calendar
- Email / message summarization
- Smart home
- Web search
- General filesystem navigation

### Platforms
- Real iOS product
- Real Windows product (partial folders only)
- Web / WASM
- Browser extension

### Training as product
- In-app SFT/DPO
- User feedback RLHF loop
- Conversation → dataset → train loop
- Distill 1.2B → 450M that keeps persona

---

## 8. RESEARCH — you already have this (not “missing features”)

You do **not** need more numbers to start a paper. You already have:

| Artifact | What it is |
|----------|------------|
| `Mitacs-Reports/BENCHMARK_REPORT.md` + logs | Model bake-off, 30/50/hard cases |
| Personal memory prefix reports + stats JSON | Recall with/without prefix |
| `memory_eval` / `memory_test` | Repeatable harness |
| Failure analyses (Billie, Kuldeep, Taylor, Sam) | Honest error taxonomy |
| `liquid_vs_transformer.md` / model research | Why LFM vs Llama/Qwen |
| SFT JSONL + generators | Training story |
| `mitacs/thesis_draft.md` + `evaluation_framework.md` | Paper skeleton |
| TTFT / tok/s / RAM numbers | Systems numbers |
| Vision + memory research notes | Multi-modal story |

**What research still lacks is not more benches. It is a clean claim + a runnable demo that matches the claim.**

---

## Feature count (rough, by bucket)

| Bucket | Count (line items above) |
|--------|---------------------------|
| STRONG | ~55 |
| DONE | ~70 |
| PARTIAL | ~35 |
| RISKY | ~16 |
| BROKEN | ~12 |
| WIP | ~20 |
| FUTURE | ~30 |
| RESEARCH | already complete enough to write |

AURA is not “missing features.” It is **over-featured and under-packaged**, with a few product-critical holes.

---

# What exactly is AURA?

AURA is a **local digital companion** — not a chatbot, not a cloud assistant, not a note app with an LLM taped on.

The face of the system is **ARIA**: a small, persistent presence that lives on your machine as a floating bar and a notebook. She is designed to stay with you while you work, talk when you tap the mic, remember who you are across days, notice the room through the camera, and occasionally speak first. The whole stack is **on-device**: Flutter UI, a Rust engine, a 1.2B Liquid Foundation Model, a separate embedder, SQLite memory, local STT/TTS, local YOLO/emotion. The point of that design is privacy and continuity — the companion is *yours*, not a session in someone else’s API.

What makes it a companion instead of “just ChatGPT offline”:

1. **It stays.** The AURA Bar is a separate window with its own life. Close the dashboard and the pill can remain. The engine does not die with the main window.
2. **It remembers.** Not “the last 8k tokens.” Structured facts, recent turns, semantic RAG, a durable file that survives reinstall. That is the research core: *personal memory that is extracted, stored, retrieved, and injected without dumping the whole diary into every prompt.*
3. **It has a body.** Waveform, particles, states (idle / listening / thinking / speaking / proactive). Voice in and voice out. A camera that can say “person, laptop, maybe waving.” The companion occupies space on the desktop, not only a text box.
4. **It has a personality.** ARIA is written as a warm, short, slightly teenage presence that is not allowed to say “as an AI.” The model is small on purpose: cheap, local, fast-enough first token, constrained style.
5. **It tries to go first.** A bandit/scheduler can fire proactive bubbles from clock, idle, notes, vision. That ambition is real even when the content is still canned.
6. **It has a second world.** Class mode is an education shell (roster, quiz, doubts, summaries) sitting on the same engine — a sketch of “companion in a student’s day,” not a finished LMS.

What AURA is **not**, today:

- Not a reliable screen-reading coding copilot (it sees the webcam, not your editor).
- Not a real reminder/calendar agent (it will *say* it will remind you).
- Not a polished always-on voice product on Linux or Android.
- Not a strong general reasoner (1.2B on CPU).
- Not a finished mobile overlay.
- Not a cloud product and not a multi-user platform.

The honest one-sentence definition for a paper or internship:

> **AURA is an on-device digital companion (persona ARIA) that combines a small local language model with persistent personal memory, a always-present desktop bar, optional camera perception, and voice — a research prototype of a private, continuous assistant that lives on the user’s machine rather than in a chat tab.**

The honest one-paragraph definition for a reviewer:

> Most assistants are stateless chats in a browser. AURA is an attempt to make the assistant a *resident*: a floating companion that shares the desktop, keeps a structured memory of the user, streams a local 1.2B model with a dedicated RAG embedder, and can see and speak without leaving the device. The research contribution is not “we trained a new frontier model.” It is the **systems + memory design** — fact extraction, hybrid retrieval, prefix injection, durable local store, and a multi-window companion UI — plus the measurements of what a 0.5–1.2B local model can and cannot recall. The product is uneven (voice, screen, reminders, Android). The companion idea, and the memory stack behind it, are real.

That is AURA.
