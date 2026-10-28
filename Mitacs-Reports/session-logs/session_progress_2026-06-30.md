# AURA Session Progress — 2026-06-30

## What We Started With
- LFM2.5 model generating "blind" — memory appended AFTER generation, LLM never saw facts
- Zero structured fact extraction — all extractors were dead code (modules never declared)
- "I remember: User's name is Lilac" repeated on EVERY response (including "What's 2+2?")
- Camera/YOLO spammed every 10 seconds at boot
- TTS spoke asterisks, dots, markdown literally ("asterisk asterisk")
- Model said "As an AI language model" and "I don't have feelings" despite system prompt
- No model comparison — only LFM tested
- 83.4% eval was measuring embedder retrieval, not LLM recall (Claude's finding)

## What We Fixed Today

### Architecture Changes
| Fix | Files | Impact |
|-----|-------|--------|
| Memory prefix injection (Option 1) | `turn.rs`, `generate.rs` | LLM now SEES facts via `[MEMORY: your name is Lilac, you love ramen]` prefix |
| "I remember" appendage REMOVED | `turn.rs` | No more repetitive tail after every response |
| Fact extraction ACTIVATED | `worker_utils/mod.rs` | All 5 extractors (name, age, prefs, insights) now called — were dead code |
| Centralized rules engine | `rules/` (9 files) | 100+ extraction patterns covering 80-85% of user memories |
| Llama-3 chat template adapter | `generate.rs`, `state.rs`, `inference.rs` | `AURA_CHAT_TEMPLATE=llama3` for Llama models |
| EOS bug fix | `inference.rs` | Restored 0x02 byte in `is_stop_token` (empty string matched everything → 0 tokens generated) |
| Cosine cutoff lowered | `search.rs` | 0.60 → 0.45 for better edge-case recall matching |

### Rules Engine (9 modules, 100+ patterns)
```
src/api/worker_utils/rules/
├── mod.rs         — dispatcher + validator (40+ allowed prefixes)
├── identity.rs    — name, age, pronouns, gender, occupation, education, languages
├── family.rs      — mom, dad, siblings, grandparents, aunts, uncles, cousins, partner, friends, children (60+ patterns)
├── pets.rs        — cats, dogs, birds, fish, etc. with names
├── preferences.rs — likes, loves, hates, favorites, hobbies, entertainment (30+ patterns)
├── location.rs    — city, country, origin, moves
├── goals.rs       — wants to learn, learning, reading, aspirations
├── emotions.rs    — mood, feelings + behavioral insights
├── events.rs      — birthday
└── edge_cases.rs  — indirect ("grew up in"), temporal ("used to"), titles ("Dr. Smith"), quantified ("three cats"), health (allergies, vegan), conditional ("usually like X but Y")
```

### System Prompt Strengthened
- ABSOLUTE RULES: never "As an AI", never "I don't have feelings", never claim user's facts as own
- `[MEMORY:]` block instructions: "those are facts about the USER — NOT about you"
- No markdown, no asterisks, no lists, no bold
- Shortened from 565 → ~200 tokens (less for small model to follow)

### TTS Cleanup
- `clean_tts_text()` strips: asterisks, markdown, dots, JSON, thinking tags, `[MEMORY:]` blocks
- No more "asterisk asterisk" or "dot dot dot" in voice

### Camera/Proactive Controls
- `AURA_CAMERA_OFF=1` env var — disables camera/YOLO/gesture watch
- `AURA_PROACTIVE_OFF=1` env var — disables proactive nudges
- Both set by default in `launch.sh` and `launch_aura.sh`
- Camera only opens when bar is visible AND camera not disabled
- CLI skips webcam init when camera off

## Models Tested (5 total)

| Model | Arch | Params | Speed | Persona | Recall | 50-case | Verdict |
|-------|------|--------|-------|---------|--------|---------|---------|
| LFM2.5-230M Q4 | Recurrent | 230M | 50 tok/s | 0/6 | 2/4 | 13% | Too small, breaks character |
| **LFM2.5-1.2B Q4** | **Recurrent** | **1.2B** | **10 tok/s** | **6/6** | **10/15** | **80%** | **BEST — warm, poetic, uses memory** |
| Qwen2.5-0.5B Q4 | Transformer | 0.5B | 15 tok/s | 2/6 | 3.5/5 | 64% | Good recall, weak persona, "as an AI" leaks |
| Llama-3.2-1B Q4 | Transformer | 1B | 8 tok/s | 4/6 | 1.5/5 | 74% | Good persona, weak recall |
| Qwen3-0.6B Q4 | Transformer | 0.6B | 15 tok/s | 0/6 | 0/5 | 0% | Base model, unusable (chain-of-thought output) |

## Final Scores (50-case hard test with all fixes)
- **LFM 1.2B: 80%** (40/50) — WINNER
- Llama 1B: 74% (37/50)
- Qwen 0.5B: 64% (32/50)

## Edge-Case Test Results (LFM 1.2B, 15 extreme facts)
- Fact extraction: 13/15 (87%)
- Storage responses: Excellent — naturally weaves multiple facts together
- Recall: Weak for edge cases (cosine matching issue — "Where did I grow up?" vs "User is from Tokyo")
- No-retrieval: Good — no spam on casual queries
- Speed: 18-22 tok/s

## Builds Deployed
- **Linux**: `build/linux/x64/debug/bundle/aura_notebook` with LFM 1.2B + all fixes
- **Android**: `app-release.apk` (102 MB) installed on R9ZXA0EEPDT
- **Rust lib**: `libaura_lnn.so` (36 MB) fresh build with all fixes

---

# Tomorrow's Plan

## 1. Proactive Features Testing (Morning)
- [ ] Test proactive popups on Linux (schedules, reminders)
- [ ] Test "remind me to X" schedule extraction
- [ ] Test natural context nudges (screen title → proactive message)
- [ ] Re-enable proactive (`AURA_PROACTIVE_OFF=0`) and test carefully
- [ ] Verify proactive doesn't spam — should fire once, not repeat

## 2. Gesture/Vision Testing (Afternoon)
- [ ] Re-enable camera (`AURA_CAMERA_OFF=0`) and test webcam
- [ ] Test "What do you see?" → camera opens, YOLO detects objects
- [ ] Test wave/gesture detection → AURA greeting
- [ ] Test camera auto-closes after watch session
- [ ] Verify camera only opens when bar is visible
- [ ] Test FER+ emotion detection (smiling, focused, tired)

## 3. Embedder Recall Improvement
- [ ] Lower cosine cutoff (done: 0.60 → 0.45) — test if edge-case recall improves
- [ ] Consider storing facts with paraphrased text for better matching
- [ ] Consider keyword-based recall fallback for "where/what/who" queries
- [ ] Add "i have" pattern for quantified pets ("I have three cats" → store count)

## 4. Android On-Device Testing
- [ ] Launch AURA on R9 — verify model download works
- [ ] Type messages — verify chat works
- [ ] Test memory: tell it your name, ask "what is my name?"
- [ ] Test voice STT — tap mic, speak, verify transcription
- [ ] Test TTS — verify AURA speaks responses
- [ ] Check if 230M is fast enough on phone (should be 30-50 tok/s)
- [ ] Consider switching to 1.2B if phone is powerful enough

## 5. Polish & Push
- [ ] Fix remaining extraction bugs (Dr. Smith title cut, double "named")
- [ ] Run full 50-case test with cosine 0.45 cutoff
- [ ] Update BENCHMARK_REPORT with final numbers
- [ ] Push everything to GitHub
- [ ] Update AGENTS.md with build/test instructions

## Known Issues to Address
1. **Embedder cosine matching** — edge-case recall queries don't match stored facts well enough (lowered to 0.45, needs testing)
2. **Dr. Smith title extraction** — period in "Dr." cuts the name (fixed in latest build, needs verification)
3. **Double "named"** — "my boss is named Karen" → "User has boss named named Karen" (fixed in latest build)
4. **Quantified pets** — "I have three cats" doesn't extract individual names
5. **Qwen3-0.6B** — base model, outputs chain-of-thought instead of responding (needs instruct variant)
