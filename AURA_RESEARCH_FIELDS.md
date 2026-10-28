# AURA — Research Fields You Can Work Independently

AURA is one companion product. Under it are **separate research layers**. Each layer has its own question, metrics, and stack. You can write a paper, internship project, or thesis chapter on **one layer** without owning the whole app.

**How to use this:** pick one field. The “isolates as” column is the smallest artifact you need (CLI, dataset, bench). The rest of AURA is just a host.

---

## Map (one page)

```
┌─────────────────────────────────────────────────────────────────────┐
│  9. HCI / Companion UI          Flutter bar, overlays, worlds       │
│  8. Education / Personal notes  course notes, quiz, summary         │
│  7. Proactive / Bandit          when to speak first                 │
│  6. Vision / Perception         camera YOLO, emotion, (not screen)  │
│  5. Voice I/O                   STT / TTS / VAD / streaming speak   │
│  4. Persona / SLM alignment     ARIA, SFT, instruction following    │
│  3. Memory / Graph RAG          AKF, ingest, retrieve, no-spam      │
│  2. Latency / Inference         TTFT, KV, LFM n_past, streaming     │
│  1. On-device systems           FFI, threads, Android/Linux, models │
└─────────────────────────────────────────────────────────────────────┘
         evaluation + privacy cut across every layer
```

Cross-cutting (not a product feature, still researchable alone):
- **E. Evaluation methodology** (recall, persona, latency, engagement)
- **P. Privacy / local-first** (what leaves the device, wipe, consent)

---

## 1. On-device systems layer

**Field names:** Edge ML systems · On-device LLM serving · Mobile/desktop runtime

**Question:** How do you run a 0.2–1.2B companion **on the user’s CPU** with Flutter + Rust, without a server?

**What AURA already has**
- Flutter UI ↔ Flutter-Rust Bridge ↔ Rust worker thread
- GGUF Q4_K_M via `llama.cpp` (`llama_cpp_2`)
- Performance tiers: Strong / Balanced / Constrained
- Linux primary; Android partial; models in `assets/` + `models/`

**You can research alone**
- Model size vs RAM vs tok/s on laptop vs phone
- Quantization (Q4_K_M vs Q4_0 vs Q8) vs quality
- Thread / context / batch knobs per device class
- Cold start vs warm start; model download / first-run
- FFI vs JNI vs platform channels (cost of each hop)
- Why LFM Gated Delta Net forbids speculative prefill

**Isolates as:** `aura_cli` + `bench_ttft` + one GGUF. No Flutter required.

### Tech stack
| Piece | Tech |
|-------|------|
| UI host | Flutter / Dart |
| Bridge | flutter_rust_bridge (FRB) |
| Engine | Rust, `llama_cpp_2`, llama.cpp |
| Weights | GGUF Q4_K_M (LFM2.5-1.2B / 230M, Llama-3.2-1B, Qwen2.5-0.5B) |
| Threads | dedicated `aura-engine-worker`, bounded `EngineMsg` channel |
| Persist | `~/.local/share/aura*` |

---

## 2. Latency / inference layer

**Field names:** LLM serving · KV-cache · Time-to-first-token · Recurrent vs Transformer on CPU

**Question:** How do you keep **TTFT low and tok/s flat** as the conversation grows, on a recurrent (LFM) model whose decode cost grows with `n_past`?

**What AURA already has**
- System-prompt KV warmup (cold ~0.78s; cache-hit TTFT ~34–55 ms in benches)
- Watermark reset at ~¾ context (between turns) so 3s→20s ramp does not happen
- Deferred fact extraction (learn **after** first token)
- Reply planner (levels 0–6 → token budget + `generate_continue`)
- Typewriter catch-up in Dart so UI does not stutter behind Rust tokens
- Measured: KV hit 39 ms vs miss 1041 ms (~26×) on 230M; 1.2B ~0.7 tok/s, ~8 GB, ~19 s/reply on CPU

**You can research alone**
- Prefill vs decode split; what to put in warmup
- Watermark / reset policy vs quality (losing history vs speed)
- Conversation recap after reset (you already inject last ~6 turns)
- Planner: short greeting vs long explain without wasting decode
- LFM (Gated Delta Net) vs Transformer (Llama/Qwen) **latency curve**, not just accuracy
- Streaming sentence-split for TTS vs TTFT

**Isolates as:** `bench_ttft`, `model_smoke`, Mitacs latency logs. Swap models, same harness.

### Tech stack
| Piece | Tech |
|-------|------|
| Runtime | llama.cpp / `llama_cpp_2` |
| Architecture under test | LFM2.5 Gated Delta Net vs Llama/Qwen Transformer |
| Cache | KV / recurrent state, `n_past`, watermark reset |
| Planner | `ReplyPlan` in `memory/embed/plan.rs` |
| Metrics | TTFT, tok/s, warmup s, RAM, `n_past` |
| SIMD | CPU (NEON / dotprod where built); Intel MKL path exists but must not be the only path |

---

## 3. Memory / graph-RAG layer  ★ core thesis layer

**Field names:** Personal knowledge graphs · Graph RAG · Continual extraction · Retrieval for companions

**Question:** How does a **small on-device model** remember a person across days **without** dumping a biography into every prompt or saying “I remember X, Y, Z”?

**What AURA already has (today)**
- SQLite WAL: turns, facts, vec_memory, summaries, insights, triggers, notes, proactive_log
- Rule extractor (8 categories)
- Hybrid retrieve: cosine + BM25 + recency (cutoff ~0.45 — too leaky)
- Always-inject `get_facts_strings(10)` → `[MEMORY: …]` spam
- 384-d BGE / Snowflake ONNX, background embed worker
- JSONL durable mirror
- Personal-memory evals (prefix vs none), 30/50/hard cases

**What the next paper is (Change 2)**
- **AKF** (AURA Knowledge Format): typed nodes, not flat strings
- **Active ingestion:** every turn → MERGE node + edges (`HAS`, `LIKES`, `LIVED_IN`, `CORRECTS`)
- **Two-pass retrieve:** vector **anchor** → 1–2 hop on SQLite edges → `[KNOW:]` only if cosine ≥ **0.62**
- “hey” injects nothing; “what’s my cat’s name?” injects only Mochi
- Pedagogy edges `REQUIRES`/`UNLOCKS` only inside **Notes**, not daily life
- SQLite graph first; Kùzu only if hops explode

This is Archipelago’s **shape** (schema + vector entry + graph walk) with a **companion ontology**, not textbooks.

**You can research alone**
- Flat facts vs typed graph vs hybrid (ablation you already sketched)
- Firewall threshold (0.45 vs 0.62 vs 0.75) vs recall vs spam
- Extraction: rules vs SLM-as-extractor vs both
- `CORRECTS` / tense (`LIVES_IN` vs `LIVED_IN`)
- Prefix format: dump vs `[KNOW:]` vs silent prefill
- Graph hop depth vs prompt tokens vs 1.2B quality
- Continual MERGE (same “Mochi” from two chats)

**Isolates as:** `memory_eval` / `memory_test` + `personal_memory_dataset.json`. No UI, no voice, no camera.

### Tech stack
| Piece | Tech |
|-------|------|
| Store | SQLite (WAL, conn pool) — `nodes` + `edges` next |
| Vectors | ONNX Runtime, BGE-small / Snowflake Arctic embed, **384-d** |
| Lexical | BM25 over same rows |
| Extract | Rust rule engine `worker_utils/rules/*` |
| Mirror | JSONL AKF objects |
| Optional later | Kùzu (embedded graph), CLIP for visual nodes |
| Eval | `memory_eval`, prefix logs, Mitacs personal-memory suite |

**Independent papers you can title**
1. *Query-anchored personal memory for sub-2B on-device companions*
2. *A typed knowledge format for lifelong user models (AKF)*
3. *When not to retrieve: cosine firewalls vs always-inject RAG*

---

## 4. Persona / SLM alignment layer

**Field names:** Character consistency · Small-model instruction following · Companion SFT

**Question:** Can a **≤1.2B** model stay ARIA (warm, short, never “as an AI”) **and** use memory when it should?

**What AURA already has**
- Compile-time persona bank (~15 JSONL cases) + system prompt
- Internal scores: 1.2B persona ~5–6/10, best voice; **worst recall** (ignores `[MEMORY:]`)
- Llama-3.2-1B: best overall persona+recall in 30-case
- 230M / 450M Aria: identity collapse (“I’m Luna”)
- SFT JSONL: chat, memory, nomemory, vision, proactive, intent
- Unsloth train script exists; not a closed product loop

**You can research alone**
- Persona vs recall tradeoff (LFM 1.2B vs Llama 1B vs Qwen 0.5B) — **already have numbers**
- SFT / DPO on “use KNOW block, don’t recite”
- Anti-recital vs anti-amnesia (two failure modes)
- Length control (planner vs SFT vs stop rules)
- Distill 1.2B → phone-small **without** losing persona

**Isolates as:** `sam_chat` / 30-case / 50-case harness + frozen memory prefix. Swap only the GGUF.

### Tech stack
| Piece | Tech |
|-------|------|
| Models | LFM2.5-1.2B / 230M, Llama-3.2-1B, Qwen2.5-0.5B/1.5B, Aria-450M VL |
| Train | Unsloth, SFT JSONL in `training_data/` |
| Prompt | ChatML, persona bank in `config/persona_bank.rs` |
| Metrics | persona score, “as an AI” leaks, recall given injection |

---

## 5. Voice I/O layer

**Field names:** On-device speech · Streaming TTS · Spoken-dialogue systems

**Question:** Can the companion **listen and speak locally** with first-audio latency that matches streaming tokens?

**What AURA already has**
- STT: sherpa-onnx Zipformer 20M int8 (often bypassed on Linux → Whisper Python)
- TTS: sherpa Piper VITS + rodio; Google-Translate online fallback
- VAD / endpoint rules; sentence-level streaming TTS
- Android: platform `SpeechRecognizer` + platform TTS
- Known breaks: Piper `sample_rate` metadata, dual `arecord` EBUSY, Whisper zombies

**You can research alone**
- Offline STT quality vs latency (Zipformer vs Whisper vs platform)
- Streaming TTS: speak-while-generate vs wait-for-full
- Endpointing (silence / max listen) vs barge-in
- When to fall back online (privacy vs reliability)

**Isolates as:** Rust `aura_cli` STT/TTS bins + wav files. No memory, no bar.

### Tech stack
| Piece | Tech |
|-------|------|
| STT | sherpa-onnx Zipformer, optional Whisper (Python), Android SpeechRecognizer |
| TTS | sherpa-onnx Piper (`en_US-lessac-medium`), rodio, Android TTS, Edge/Google fallback |
| Capture | `arecord` / V4L-adjacent ALSA, platform mic |
| VAD | sherpa endpoint rules |

---

## 6. Vision / perception layer

**Field names:** On-device perception · Multimodal context for agents · Visual memory

**Question:** What should a **desktop companion** see, and how does that become **graph nodes** instead of polluting identity facts?

**What AURA already has**
- Webcam: V4L2 / CameraX
- YOLOv8n objects + pose, FER+ emotion, motion-wave heuristic
- Vision gate (confidence + cooldown) → `vision:` **facts** (wrong table)
- VLM weights exist (LFM2.5-VL 450M / 1.6B); not a clean product loop
- Screen OCR plugin (tesseract) — coded, **not reliable**; biggest product hole

**You can research alone**
- Camera events → `kind=vision` nodes (not identity)
- When vision should enter Pass 1 (only vision-classified turns)
- Screen OCR vs camera (two different papers)
- VLM vs YOLO+text for “what’s in front of me”
- Cooldown / importance so the graph does not fill with “laptop visible”

**Isolates as:** `real_vision_test` / YOLO scripts + saved frames. Memory can be a mock store.

### Tech stack
| Piece | Tech |
|-------|------|
| Detect | YOLOv8n ONNX, YOLOv8n-pose, FER+ ONNX |
| Capture | V4L2, CameraX, `scrot` (screen, partial) |
| OCR | tesseract (plugin) |
| VLM | LFM2.5-VL GGUF + mmproj (`llama.cpp` mtmd) |
| Gate | Rust `VisionGate` |

---

## 7. Proactive / bandit layer

**Field names:** Proactive agents · Contextual bandits · Interruption science

**Question:** When should a resident companion **speak first**, and how do you learn that **on-device** without reciting the user’s birthday?

**What AURA already has**
- Epsilon-greedy bandit over trigger rows in SQLite
- Engagement recording (did the user respond)
- Clock / idle / schedule-note checks
- Overlay bubbles
- Content often canned or fact-contaminated
- **No real timer** (“remind me in 2 min” is a lie)

**You can research alone**
- Bandit vs fixed schedule vs random (your eval framework Study 2)
- Features: idle minutes, last vision, typing, time of day
- Reward: reply within 30s vs dismiss vs SILENT
- Content policy: **zero stored facts** unless the trigger is a real reminder
- Real reminders = a **clock subsystem**, not the LLM (separate small paper)

**Isolates as:** `proactive_real_test` + logged idle sessions. Can stub the LLM with canned lines.

### Tech stack
| Piece | Tech |
|-------|------|
| Policy | epsilon-greedy in `memory/store/bandit.rs` |
| Store | `triggers`, `proactive_log` |
| Scheduler | Dart `proactive_scheduler` |
| Signal | bar last-interaction, optional vision snippet |

---

## 8. Education / personal-notes layer (ex-ClassSync)

**Field names:** Personal learning systems · Note-grounded QA · Pedagogical graphs

**Question:** Can the **same AKF + hop RAG** ground quiz / summary / doubts on **my notes**, using `REQUIRES`/`UNLOCKS` only inside a course?

This is the **only** place Archipelago’s pedagogical OKF belongs.

**What AURA already has**
- Local class CRUD, AI quiz, doubt queue, lesson summariser (LLM-wired)
- Fake peers: codes, roster, attendance, leaderboard — **cut**

**You can research alone**
- Course = `kind=course`, note = `kind=note`, ABOUT / REQUIRES / UNLOCKS
- Retrieval restricted to one course subgraph
- Quiz generation grounded vs ungrounded (hallucinated MCQ)
- “What should I study next?” = forward `UNLOCKS` hop

**Isolates as:** one course JSONL + `sam_chat` with a course-scoped retrieve flag.

### Tech stack
| Piece | Tech |
|-------|------|
| UI | Flutter class_mode → Notes |
| Store | same SQLite nodes/edges + `aura_classes.db` until merged |
| Ingest | `FileSense` + STT-to-note |
| QA | same local LLM, **filtered retrieve** |

---

## 9. HCI / companion-UI layer

**Field names:** Peripheral displays · Always-on agents · Multi-window desktop AI

**Question:** What is the **body** of a local companion — a bar that stays when the dashboard dies — and when does that body become hostile (overlay steal, spam bubbles)?

**What AURA already has**
- Linux multi-window bar, tray, states, waveform, particles
- Android overlay: known broken (FGS, tap steal, keyboard)
- Worlds: AURA vs Class/Notes

**You can research alone**
- Presence vs interruption (idle pill vs proactive bubble)
- Desktop window lifecycle (engine stays, main hides)
- Mobile: in-app pill vs system overlay (policy + UX)
- Trust UI: notebook, wipe, “what I know about you”

**Isolates as:** Flutter-only mock brain (no Rust) for UX studies; or Wizard-of-Oz.

### Tech stack
| Piece | Tech |
|-------|------|
| UI | Flutter, `desktop_multi_window`, `window_manager` |
| Android | `flutter_overlay_window` (v1.1 only) |
| Motion | custom painter waveform/particles, some Rive assets |

---

## E. Evaluation methodology (cross-cutting)

**Field names:** Holistic eval for companions · On-device LLM benchmarks

**Question:** What do you measure if “accuracy” is not MMLU — but **recall + persona + silence + latency**?

**What you already have (do not rebuild)**
- 30/50/hard cases, personal-memory 1000, prefix vs raw
- Billie / Kuldeep / Taylor / Sam QA taxonomies
- Ablation tables in `mitacs/evaluation_framework.md` (RQ1–RQ4)
- Charts + `dashboard.html`

**You can research alone**
- A companion scorecard: Recall@ask, Spam@chitchat, Persona leak rate, TTFT, Engagement@proactive
- Human ratings vs automatic (fact-in-reply when not asked = fail)

**Isolates as:** JSONL suites + scoring scripts. Swap any layer underneath.

### Tech stack
Python eval scripts, Rust `memory_eval` / `integration_test`, matplotlib, stored logs under `Mitacs-Reports/`.

---

## P. Privacy / local-first (cross-cutting)

**Field names:** On-device privacy · Data minimization for agents

**Question:** What is the **minimum** that must be stored for a companion to feel continuous, and how do you prove nothing left the machine?

**Already:** offline-first, optional online TTS/translate (opt-in), wipe, JSONL on disk, no account.

**Research:** memory minimization, vision retention policy, store Data-safety mapping, “right to be forgotten” on a graph (`CORRECTS` + delete hops).

---

## Full tech stack (one table)

| Layer | Languages | Models / libs | Data |
|-------|-----------|---------------|------|
| UI | Dart / Flutter | window_manager, overlay plugin, Rive | — |
| Bridge | Dart + Rust | flutter_rust_bridge | — |
| LLM | Rust | llama.cpp, LFM / Llama / Qwen GGUF | KV / recurrent state |
| Embed | Rust | ONNX Runtime, BGE-small 384-d | `vec_memory` / node embeddings |
| Memory | Rust + SQL | SQLite WAL, (later optional Kùzu) | facts → **nodes/edges**, JSONL |
| Extract | Rust | rule engine (optional later SLM pass) | AKF JSON |
| Voice | Rust + Dart + (Py Whisper) | sherpa-onnx, Piper, rodio, platform STT/TTS | wav / PCM |
| Vision | Rust + Dart | YOLOv8n, FER+, tesseract, optional VL GGUF | frames, `vision` nodes |
| Proactive | Rust + Dart | epsilon-greedy bandit | triggers, log |
| Notes | Dart + same memory | FileSense, local class DB | course subgraph |
| Train / eval | Python | Unsloth, matplotlib, custom harnesses | `training_data/`, Mitacs logs |
| Ship | Linux + Android | `.desktop` / Play listing | on-device only |

**Not in the stack (on purpose):** cloud chat API, Kùzu (until hops hurt), 1024-d embedder, Gemini synthesizer, peer ClassSync network.

---

## How to pick a field (internship / paper)

| If you want… | Take this layer | You already have |
|--------------|-----------------|------------------|
| Strongest original claim | **3 Memory / Graph RAG** | benches + failure cases; Change 2 is the paper |
| Systems / performance | **2 Latency** | TTFT, KV 26×, LFM `n_past` story |
| Model comparison | **4 Persona + SLM** | LFM vs Llama vs Qwen table |
| HCI | **9 UI** or **7 Proactive** | bar + bandit + QA notes |
| Multimodal | **6 Vision** | YOLO real, screen still open |
| Speech | **5 Voice** | sherpa + known Linux bugs |
| EdTech | **8 Notes** | quiz/summary hooks; cut peers |
| Mobile systems | **1 On-device** | Android overlay as a **negative** result is publishable |

**One-sentence thesis (memory, recommended):**

> A typed personal graph plus query-anchored two-pass retrieval lets a 1.2B on-device companion remember a user across sessions without always-inject RAG or “I remember…” recital.

Each layer above is a chapter. The product is just the chapters running in one process.
