# AURA Session Progress — Day 1 (2026-06-30)

## What We Started With
- LFM2.5 model generating "blind" — memory appended AFTER generation, LLM never saw facts
- Zero structured fact extraction — all extractors were dead code
- "I remember: User's name is Lilac" repeated on EVERY response
- Camera/YOLO spammed every 10 seconds at boot
- TTS spoke asterisks, dots, markdown literally
- Model said "As an AI language model" despite system prompt
- No model comparison — only LFM tested
- 83.4% eval was measuring embedder retrieval, not LLM recall

## What We Fixed

### 1. Memory Injection (Option 1)
- `[MEMORY: your name is Lilac, you love ramen]` prefix injected before user message
- LLM now SEES facts and can reason over them
- "I remember" appendage REMOVED — no more repetitive tail

### 2. Centralized Rules Engine (9 modules, 100+ patterns)
```
src/api/worker_utils/rules/
├── mod.rs         — dispatcher + validator (50+ allowed prefixes)
├── identity.rs    — name, age, pronouns, gender, occupation, education, languages (30+ patterns)
├── family.rs      — mom, dad, siblings, grandparents, aunts, uncles, cousins, partner, friends, children (60+ patterns)
├── pets.rs        — cats, dogs, birds, fish, etc. with names
├── preferences.rs — likes, loves, hates, favorites, hobbies, entertainment (30+ patterns)
├── location.rs    — city, country, origin, moves
├── goals.rs       — wants to learn, learning, reading, aspirations
├── emotions.rs    — mood, feelings + behavioral insights
├── events.rs      — birthday
└── edge_cases.rs  — indirect ("grew up in"), temporal ("used to"), titles ("Dr. Smith"), quantified ("three cats"), health (allergies, vegan), conditional ("usually like X but Y")
```

### 3. System Prompt Strengthened
- ABSOLUTE RULES: never "As an AI", never "I don't have feelings", never claim user's facts as own
- [MEMORY:] block instructions: "those are facts about the USER — NOT about you"
- No markdown, no asterisks, no lists
- Shortened from 565 → ~200 tokens

### 4. TTS Cleanup
- `clean_tts_text()` strips asterisks, markdown, dots, JSON, thinking tags, [MEMORY:] blocks

### 5. Camera/Proactive Controls
- `AURA_CAMERA_OFF=1` — disables camera/YOLO/gesture watch
- `AURA_PROACTIVE_OFF=1` — disables proactive nudges
- Both set by default in launch scripts
- Camera only opens when bar is visible AND camera not disabled

### 6. Llama-3 Chat Template Adapter
- `AURA_CHAT_TEMPLATE=llama3` for Llama models
- Added `<|eot_id|>` to stop tokens

### 7. EOS Bug Fix
- `is_stop_token` had empty string `""` (matched everything → 0 tokens generated)
- Restored 0x02 byte

### 8. Persistent Memory on Android
- Memory DB stored at `/storage/emulated/0/AURA/aura_memory.db`
- Survives app uninstall+reinstall
- Model files at `/storage/emulated/0/AURA/models/`

## Models Tested (5 total)

| Model | Arch | Params | Speed | Persona | Recall | 50-case | Verdict |
|-------|------|--------|-------|---------|--------|---------|---------|
| LFM2.5-230M Q4 | Recurrent | 230M | 50 tok/s | 0/6 | 2/4 | 13% | Too small |
| **LFM2.5-1.2B Q4** | **Recurrent** | **1.2B** | **10 tok/s** | **6/6** | **10/15** | **80%** | **BEST** |
| Qwen2.5-0.5B Q4 | Transformer | 0.5B | 15 tok/s | 2/6 | 3.5/5 | 64% | Weak persona |
| Llama-3.2-1B Q4 | Transformer | 1B | 8 tok/s | 4/6 | 1.5/5 | 74% | Good persona |
| Qwen3-0.6B Q4 | Transformer | 0.6B | 15 tok/s | 0/6 | 0/5 | 0% | Base model, unusable |

## Final Winner: LFM2.5-1.2B (80%)

## Edge-Case Test Results (LFM 1.2B)
- Fact extraction: 13/15 (87%)
- Multi-fact sentence: "I live in Vancouver with my cat Pixel" → extracted BOTH facts
- Indirect: "I grew up in Tokyo" → extracted
- Temporal: "I used to live in Toronto" → extracted
- Health: "I'm allergic to peanuts", "I'm vegan" → extracted
- Conditional: "I usually like horror but sometimes comedy" → extracted BOTH
- Recall: Weak for edge cases (cosine matching — lowered to 0.45)
- No-retrieval: Good — no spam on casual queries

## Files Modified Today
- `src/api/chat/turn.rs` — memory prefix injection, appendage removed, build_memory_prefix
- `src/api/tts/core.rs` — clean_tts_text()
- `src/api/worker_utils/mod.rs` — activated all extractor modules
- `src/api/worker_utils/memory.rs` — calls rules engine
- `src/api/worker_utils/rules/` — 9 new files, 100+ extraction patterns
- `src/api/engine/paths.rs` — Android persistent storage
- `src/llama_engine/generate.rs` — Llama-3 template adapter
- `src/llama_engine/inference.rs` — EOS fix, eot_id stop token
- `src/llama_engine/state.rs` — Llama-3 warmup format
- `src/memory/store/search.rs` — cosine cutoff 0.50→0.45
- `src/memory/store/facts.rs` — expanded allowed prefixes
- `examples/persona_cases/system_prompt.txt` — ABSOLUTE RULES
- `aura_notebook/lib/services/bar_brain/bar_brain_engine.dart` — camera/proactive off
- `aura_notebook/lib/services/bar_brain/bar_brain_ui.dart` — bar visibility gating
- `aura_notebook/lib/screens/loading_screen/constants.dart` — LFM 1.2B config
- `aura_notebook/lib/screens/loading_screen/android_logic.dart` — AURA/models path
- `aura_notebook/launch.sh` + `launch_aura.sh` — camera/proactive off by default

## Current Build Status
- **Linux**: Working, LFM 1.2B, all fixes applied
- **Android**: APK built (106 MB), FRB hash mismatch issue (needs Android .so cross-compile)
- **Blocker**: sherpa-onnx doesn't have Android aarch64 prebuilts — need to build without voice feature for Android or find prebuilts

---

# Tomorrow's Plan

## 1. Android Build Fix (Morning — HIGH PRIORITY)
- [ ] Fix sherpa-onnx Android build (build without voice feature or find prebuilts)
- [ ] Cross-compile `libaura_lnn.so` for `aarch64-linux-android`
- [ ] Replace jniLibs .so with fresh build
- [ ] Fix FRB content hash mismatch (Dart ↔ Rust must be from same build)
- [ ] Install APK, push model to `/storage/emulated/0/AURA/models/`
- [ ] Verify app loads, model found, engine initializes

## 2. Proactive Features Testing (Afternoon)
- [ ] Re-enable proactive (`AURA_PROACTIVE_OFF=0`) on Linux
- [ ] Test "remind me to X" schedule extraction
- [ ] Test natural context nudges (screen title → proactive message)
- [ ] Verify proactive fires once, not repeated
- [ ] Test on Android if build is ready

## 3. Gesture/Vision Testing
- [ ] Re-enable camera (`AURA_CAMERA_OFF=0`) on Linux
- [ ] Test "What do you see?" → camera opens, YOLO detects
- [ ] Test wave/gesture → AURA greeting
- [ ] Test camera auto-closes after watch session
- [ ] Verify camera only opens when bar is visible

## 4. Embedder Recall Improvement
- [ ] Test cosine 0.45 cutoff — does edge-case recall improve?
- [ ] Consider storing facts with paraphrased text for better matching
- [ ] Consider keyword-based recall fallback for "where/what/who" queries
- [ ] Add "i have" pattern for quantified pets

## 5. Remaining Extraction Bugs
- [ ] Fix Dr. Smith title extraction (period in "Dr." cuts the name)
- [ ] Fix double "named" ("my boss is named Karen" → "named named Karen")
- [ ] Add "my best friend is X" without "named"
- [ ] Add birthday patterns ("my birthday is March 15")

## 6. Full App Testing (Day 2-3)
- [ ] Run 50-case test with cosine 0.45 on LFM 1.2B
- [ ] Test voice STT on Android (tap mic, speak, verify transcription)
- [ ] Test TTS on Android (verify AURA speaks, no asterisks)
- [ ] Test memory persistence (uninstall + reinstall → memories survive)
- [ ] Test bar overlay on Android
- [ ] Performance profiling on phone

## 7. Polish & Push (Day 3)
- [ ] Update BENCHMARK_REPORT with final numbers
- [ ] Update AGENTS.md with build/test instructions
- [ ] Push everything to GitHub
- [ ] Tag release

## Known Issues
1. **Android .so cross-compile** — sherpa-onnx lacks Android prebuilts (build without voice or find alternative)
2. **FRB hash mismatch** — Dart and Rust must be from same build cycle
3. **Embedder cosine matching** — edge-case recall queries don't match stored facts well (lowered to 0.45)
4. **Dr. Smith title extraction** — period in "Dr." cuts the name
5. **Double "named"** — "my boss is named Karen" → "named named Karen"
