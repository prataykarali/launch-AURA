# AURA Dev TODO
_Generated: 2026-06-26 — accuracy push + vision/file-sense sprint_

---

## ✅ Done (this session)

| # | What | Where |
|---|------|--------|
| 1 | **Fixed compile bug** — duplicate `fn adaptive_memory_limit` in `api/engine.rs` (two definitions: 12/5 and 50/12) | `src/api/engine.rs` |
| 2 | **Scan ALL vec_memory rows** — removed `LIMIT scan_limit` so timestamp-sorted rows can't evict old-but-relevant facts | `src/memory/store/mod.rs` |
| 3 | **Proper BM25 IDF scoring** — two-pass Robertson IDF × TF-norm (K1=1.5, B=0.75) replaces fixed-weight lexical score | `src/memory/store/mod.rs` |
| 4 | **Better LLM instruction** — removed "under 15 words" cap that killed multi-fact synthesis; model now told to answer ALL parts and never claim amnesia when facts are present | `src/llama_engine.rs` |
| 5 | **Better pre-fill** — `"Based on what I remember,"` → `"Based on what I know about you,"` to reduce amnesia-adjacent pattern activation | `src/llama_engine.rs` |
| 6 | **File sense module** — `src/api/file_read.rs`: reads .md/.txt/any UTF-8 file, 300-char chunks with 50-char overlap, embeds with BgeTextEmbedder → vec_memory permanent RAG | `src/api/file_read.rs` |
| 7 | **Bar voice latency reduced** — desktop bar now speaks completed sentences during streaming instead of waiting for full LLM completion | `../../aura_notebook/lib/services/bar_brain_generation.dart` |
| 8 | **Free online TTS fallback hardened** — removed Edge TTS from the active path; uses configured free HTTP TTS or Google Translate TTS, with immediate local offline fallback | `src/api/tts.rs`, `../../aura_notebook/lib/services/tts_service.dart` |
| 9 | **Camera window no longer opens at boot** — webcam window starts only for vision queries and auto-closes after a watch session | `src/api/engine.rs`, `src/vision/webcam.rs` |
| 10 | **Natural context nudges expanded** — screen/vision labels, speech, and text observations feed model-generated proactive nudges; gesture signals can trigger immediately, repeated screen patterns can trigger after several minutes | `../../aura_notebook/lib/services/natural_context_service.dart`, `../../aura_notebook/lib/services/bar_brain.dart` |
| 11 | **Notebook file import wired** — Notebook import button uses local Linux file chooser and calls the Rust file-sense bridge to embed readable files into memory | `../../aura_notebook/lib/services/file_sense_service.dart`, `../../aura_notebook/lib/screens/notebook_page.dart` |
| 12 | **Desktop bar click-through blocker reduced** — Linux child bar starts compact and only expands while a response/proactive bubble is visible, so transparent overlay space no longer blocks buttons behind it | `../../aura_notebook/lib/bar/bar_window_app.dart`, `../../aura_notebook/linux/runner/my_application.cc` |

---

## 🔲 Accuracy (Mitacs 1000-test eval)

- [ ] Run eval against updated framework. Baseline: 71.7%. Target: 85%+.
- [ ] Tune BM25 (K1, B, bm25_scaled multiplier) if specific test categories stall.
- [ ] **Multi-fact pre-fill variant** — for `wants_broad_memory(prompt)` use `"Here's what I know about you: "` instead of generic pre-fill.
- [ ] **Char-budget cap on facts injection** — when `adaptive_facts_limit=200` for broad queries, add a hard 2000-char ceiling so instruction fits in context.

---

## 🔲 Aura Bar — issues found in code audit

1. **Short-query fast-path skips semantic RAG** for `word_count ≤ 8 && !has_deep_verb`. Misses memory-recall queries like "what did we work on?". Fix: add RAG for queries containing recall verbs ("remember", "what did", "last time").
2. **`[BRIEF]` brevity instruction injected into facts block** (memories[0]), not as a system message. Minor format issue.
3. **No embed timeout guard** — a 9-word deep query still blocks the worker on embed_query (~150ms); can stack with generation latency.
4. **Proactive context too large for Bar** — `get_proactive_context()` can send ~600 chars to a 64-token Bar response — overwhelms the answer budget. Need a shorter proactive budget in `is_brief` mode.
5. **AURA companion behavior target** — AURA should combine screen, camera, speech, and typed text into a natural context model, then occasionally produce model-written English nudges without canned phrases. Examples: noticing sustained Rust/coding practice, prolonged short-video scrolling, or a wave/gesture.

## 🔲 Free-only AURA companion pass (2026-06-28)

- [x] **No paid APIs** anywhere in voice/translation/proactive sensing. Online providers must be free endpoints only, with local/offline fallback.
- [x] **Remove Edge TTS completely from active app paths**. Preferred online TTS order: `AURA_ONLINE_TTS_URL` if configured, then free Google Translate TTS, then offline Rust sherpa/piper voice. Logs should name the provider used.
- [x] **Verify multilingual speech path**: local/free STT first, then Google Translate-to-English when online, then offline transliteration/passthrough. AURA should always reply in English.
- [x] **Bar response discipline**: AURA bar replies must stay at 1-2 short sentences and should start TTS as soon as useful text/sentence chunks arrive.
- [x] **Camera privacy**: webcam window must not open at boot. It should pop up only for explicit watching/vision/gesture queries and auto-close after the watch session.
- [x] **Natural companion nudges**: screen, camera, speech, and text observations feed a natural-context model. AURA may occasionally say model-written English nudges, e.g. noticing Rust practice or several minutes of reels, without hard-coded canned popup text.
- [x] **Gesture/vision response**: when explicit watch mode sees a wave/hand gesture or notable action, route it into the same natural-context pipeline so AURA can respond naturally.
- [x] **Overlay click blocker**: compact desktop bar state should not reserve the full response-bubble rectangle and block clicks behind transparent pixels.

## 🔲 Smooth-first device guardrails (2026-06-28)

- [x] Detect a runtime performance profile from platform, CPU parallelism, and `/proc/meminfo` when available.
- [x] Strong devices get the strongest smooth profile: more LLM/Rayon threads, 3072 context, 512 batch, larger response ceiling, and continuations.
- [x] Mid/weak phones and laptops deduce down to balanced/constrained profiles: smaller context, smaller batch, fewer worker threads, smaller token ceilings, brief-query RAG skipping, and no continuation loops.
- [x] Add runtime downgrade: if observed generation speed stays slow, lower future turns to a smoother profile instead of continuing to push the device.
- [ ] **Android proactive overlay routing**: proactive bar events must update/speak inside the floating overlay instead of redirecting/opening the main AURA app.
- [ ] **Android STT reliability**: mic/listen/finalize path currently fails on device; verify permission, speech recognizer availability, final-result capture, and overlay/background service interaction.
- [ ] **Android TTS smoothness**: platform TTS is slow/choppy under streaming chunks; keep it warm, serialize utterances, and avoid repeated online/network fallback on Android.
- [ ] Wire a Dart-visible diagnostics row for the active performance profile and latest downgrade reason.
- [ ] Add optional model-variant loading when multiple GGUFs exist: strongest quant on strong devices, smaller quant on constrained devices.
- [ ] Add an emergency OOM/crash recovery marker so next boot starts constrained if the previous boot died during model init/generation.

---

## 🔲 Vision / File Sense

### File sense (✅ Rust + Dart side done)
- [x] Run `flutter_rust_bridge_codegen generate` to expose `aura_read_file_into_memory` to Dart
- [x] Dart `FileSenseService` — file picker → `auraReadFileIntoMemory()` → confirmation toast

### Camera vision (images, live camera) — `docs/vision_memory_plan.md`
Milestone 1 (pipeline stub with VisionGate / VisionEvent) ✅ complete.
- [ ] **M2**: MediaPipe ObjectDetector (TFLite, ~2MB Flutter plugin) for real detections
- [ ] Add a real free local hand/pose landmark model for wave/gesture detection. Current Rust webcam gesture detection is motion-based and can identify likely waving when a person is in view, but YOLOv8n cannot classify hand gestures by itself.
- [ ] Add a real free local face/expression model for `face_visible`, `smiling`, `confused_expression`, `focused_expression`, and `tired_expression`. Natural-context hooks are ready, but the app must not claim emotion/expression detection until this model is actually wired and validated.
- [ ] **M3**: Visual context injection — max 3 vision lines when query asks about surroundings
- [ ] **CLIP image embeddings**: add `ClipVisionEmbedder` in `src/memory/embed.rs` using CLIP-ViT-B/32 ONNX, separate `visual_vec_memory` table to avoid polluting text cosine search

## 🔲 Free Multilingual Voice / Translation

- [x] STT: Linux Whisper server transcribes multilingual speech locally/free, then Dart translates transcript to English.
- [x] Translation: online free Google Translate endpoint first; offline transliteration/passthrough fallback if internet is down.
- [x] TTS: no paid APIs and no Edge dependency in active path; use Google Translate TTS or `AURA_ONLINE_TTS_URL`, then offline Rust TTS.
- [ ] Add a visible diagnostics row for `translation_source` and online/offline TTS source so failures are obvious in the UI, not only logs.

---

## 🔲 Cleanup

- [ ] `src/bin/` and `examples/` already empty — nothing to move
- [ ] Fix `deprecated` warnings in `llama_engine.rs` (`token_to_str` → `token_to_piece`)
- [ ] Confirm Mitacs test harness at `launch-AURA/Mitacs/` points to updated library
- [x] Investigate why desktop TTS falls back away from online EdgeTTS despite internet access; log socket/DNS/backoff cause before local/offline fallback. Result: Edge endpoint returns HTTP 403, so Edge was removed from the active path.
