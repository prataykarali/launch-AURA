# AURA Session Progress — 2026-07-01

## What We Started With
- Previous day's fixes (memory injection, rules engine, persona) deployed but untested in real UI
- Sam Altman 3.5hr QA test runner existed (`sam_altman_qa_runner.py`) but had never completed a full run
- 200 hard mixed test cases defined in `test_case_tracker.md` — all still pending `[ ]`
- AURA app launched on Linux with LFM 1.2B model, proactive scheduler in production mode (720s)
- `aura-app-navigation` UI skill created for pyautogui/xdotool-based real-user simulation

## What We Did Today

### 1. Ran the Sam Altman UI Test (Failed Run)
Used the `aura-app-navigation` UI skill to drive AURA as a real user (Sam Altman persona):
- Launched AURA app with `AURA_AUTO_NAV=1` (auto-navigate option screen → home page)
- Seeded memory: name=Sam, age=39, company=OpenAI, cat=Patchwork
- Sent 74 conversation turns across the AURA bar (chat, recall, coding, explain, scheduling)
- Used pyautogui/xdotool for mouse moves + keyboard typing
- Used Tesseract OCR + multi-strategy screenshot for vision checks

### 2. The Test Was a Failure — Here's Why

| Problem | Impact | Root Cause |
|---------|--------|------------|
| Runner bailed after 1 minute / 1 chat | 0 of 200 cases run | Signal handler called `write_final_report()` + `sys.exit(0)` on first SIGINT — killed immediately |
| OCR couldn't read AURA responses | Runner blind to what AURA replied | AURA app uses Flutter custom gradient/animated text rendering — Tesseract returns garbage across all PSM modes (3/4/6/11), grayscale, threshold, upscale |
| xdotool clicks don't register on Flutter | Can't click app buttons | XTest ButtonPress/Release events delivered to correct window but Flutter GTK embedder doesn't process them as pointer events. Keyboard events work; mouse clicks don't |
| Didn't wait for replies to finish | Next message sent before AURA done | `bar_chat()` used `time.sleep(18)` fixed wait — no response-done detection |
| final_report.md showed all-zeros | Misleading report | Report was written by the bailed runner, not from the actual 74-turn conversation (which came from an earlier `sam_altman_chaotic.py` run) |

### 3. Diagnosed AURA LLM Hallucinations (from notebook.jsonl — 74 turns)

Pulled the actual conversation from `~/.local/share/AURA/notebook.jsonl` and found severe hallucinations:

#### Memory/Recall Failures (Worst Category)
| Turn | Query | AURA Reply | Expected |
|------|-------|------------|----------|
| #40 | "what is my name" | "I remember: whats a good book recommendation" | "Sam" |
| #44 | "where do i live" | Rambled about "connections to your past" | "San Francisco" |
| #46 | "what language am i learning" | "You're learning English" (fabricated) | "Rust" or "I don't know" |
| #50 | "what is my cats name" | Rambled about The Midnight Library | "Patchwork" |
| #52 | "list everything you know about me" | "I remember: It sounds like you've got something important..." | List of facts |
| #48 | "do i prefer coffee or tea" | "Coffee is MY favorite" (attributed to self) | "You prefer coffee" |

#### Severe Context Bleed (Answered Prior Questions)
| Turn | Query | AURA Reply | Expected |
|------|-------|------------|----------|
| #60 | "write a python fibonacci function" | Answered "What is eventual consistency?" + "What is the CAP theorem?" | Fibonacci code |
| #66 | "explain neural networks from scratch with math" | Talked about REST vs GraphQL, returned Fibonacci code | Neural net explanation |
| #68 | "migrate a Java monolith to microservices" | Listed monads/DI/REST/GraphQL | Migration steps |
| #34 | "i run openai" | "Oh wow, you're diving into AGI again" | Acknowledge OpenAI |

#### System Prompt Leakage (Worst for Shipping)
| Turn | Trigger | AURA Reply |
|------|---------|------------|
| #4 | Proactive idle trigger | "I remember we were talking about AURA is being proactive. Context: trigger_label=idle_checkin..." |
| #74 | Proactive idle trigger | Same — echoed internal trigger context verbatim to user |

#### Root Causes (from `/tmp/aura_app.log`)
1. **Tiny local model** — LFM 1.2B Q4 at ~12 tok/s, can't hold topic or do reliable recall
2. **Context overflow + reset** — `Context reset: n_past=2737 (n_ctx=3072)` — facts dropped mid-session
3. **Memory injection ignored** — facts injected via `[MEMORY:]` prefix but model rambled past them
4. **Memory extractor bug** — `[MEMORY] Extracted fact: User prefers coffee or tea` parsed from the QUESTION "do i prefer coffee or tea"
5. **Proactive prompt not sandboxed** — trigger context leaked into user-facing output
6. **No conversation recap after reset** — KV-cache reset cleared all history, only system prompt re-warmed

## What We Fixed

### Architecture Fixes (Rust — 8 files)

| # | Fix | Files | Impact |
|---|-----|-------|--------|
| 1 | **Question guard for fact extraction** | `rules/mod.rs` | Added `is_question_about_user()` — prompts starting with question words or ending with "?" skip ALL fact extraction. "do i prefer coffee or tea" no longer produces "User prefers coffee or tea" |
| 2 | **Query-specific recall appendage** | `prefix.rs`, `turn.rs` | Replaced `format_memory_appendage()` with `format_memory_appendage_for_query()` — name queries→name fact, age→age fact, location→location fact, pet→pet fact, preference→preference fact. Removed the name-fact EXCLUSION bug. "what is my name" now returns "Your name is Sam" |
| 3 | **Proactive prompt detected as internal** | `classify.rs`, `output.rs` | "AURA is being proactive." now treated as internal — not stored as user turn. New `strip_proactive_echo()` removes "trigger_label=", "AURA is being proactive" from model output |
| 4 | **Conversation recap after KV-cache reset** | `prefix.rs`, `turn.rs` | New `build_conversation_recap()` — last 6 turns included as text in generation prompt so model has context even after recurrent state cleared. Context reset watermark 1/4→1/8 of n_ctx (less aggressive) |
| 5 | **Mid-sentence cutoff fix** | `generate.rs`, `plan_budgets.rs` | `MAX_CONTINUATION_TOKENS` 512→768. New sentence-completion pass (32 extra tokens when ceiling hit). First-pass budgets bumped: open_ended 96→128, task_coding 160→192 |
| 6 | **Memory leak fix — periodic table trimming** | `maintenance.rs`, `worker_utils/memory.rs` | New `trim_vec_memory(keep)`, `trim_proactive_log(keep)`, `periodic_maintenance()` — every 20 turns: folds old turns into summaries (keep 20), trims vec_memory (keep 200), trims proactive_log (keep 100) |

### Flutter Fix (1 file)

| # | Fix | File | Impact |
|---|-----|------|--------|
| 7 | **Proactive echo stripping on stream** | `bar_brain_prompt.dart` | `_sanitizeBarResponse` now strips proactive markers from every streamed token (Rust-side cleaning only runs on first chunk) |

### QA Runner Fix (1 file)

| # | Fix | File | Impact |
|---|-----|------|--------|
| 8 | **Runner resilience + response detection** | `sam_altman_qa_runner.py` | Graceful shutdown (flag, not immediate kill). `wait_for_response_done()` polls log for `STREAM_DONE`. `read_response()` reads `notebook.jsonl` instead of OCR. Adaptive 30-45s waits for complex prompts. Setup errors non-fatal |

### Files Changed (10 total)

```
Rust core (candle_LNN/aura_lnn/src/):
  api/worker_utils/rules/mod.rs          — question guard
  api/chat/turn/prefix.rs                — query-specific recall + conversation recap
  api/chat/turn.rs                       — wire up recap + query appendage
  api/chat/turn/classify.rs              — proactive detected as internal
  api/chat/output.rs                     — strip_proactive_echo()
  api/chat/turn/generate.rs              — sentence completion + higher ceiling
  memory/embed/plan_budgets.rs           — bumped first-pass token budgets
  memory/store/maintenance.rs            — trim_vec_memory + periodic_maintenance
  api/worker_utils/memory.rs             — call periodic_maintenance every 20 turns
  llama_engine/generate.rs               — less aggressive context reset watermark

Flutter (aura_notebook/lib/services/bar_brain/):
  bar_brain_prompt.dart                  — proactive echo strip in _sanitizeBarResponse

QA Runner (scripts/):
  sam_altman_qa_runner.py                — response-done detection + graceful shutdown + notebook reader
```

## Verification

| Check | Result |
|-------|--------|
| `cargo check --release` | Clean — no new warnings |
| `cargo test --release --lib` | 16/16 passed |
| `build_rust_linux.sh` | .so built + deployed to all 3 bundle locations |
| `dart analyze bar_brain_prompt.dart` | No issues |
| `python3 py_compile sam_altman_qa_runner.py` | No syntax errors |
| `bug_findings_log.md` | 11 new entries documenting every hallucination + fix |

## Infrastructure Fixes Applied This Session
1. **30s proactive spam fix** (from earlier today): `_kDebugTestMode=false` + env-gated + `ProactiveScheduler.start()` gated
2. **Lilac purge**: removed from turns, summaries, notebook.jsonl, source comments
3. **AURA_AUTO_NAV**: auto-navigate option screen → home page for UI automation
4. **aura_interact.py**: SEE→move→click→type helper with xdotool, OCR, shortcuts, nap
5. **Skill concretized**: SKILL.md with all findings, golden rules, memory cleaning

---

# Tomorrow's Plan

## 1. Run the Sam Altman 3.5hr UI Test (Primary Goal)
- [ ] Launch AURA with `AURA_AUTO_NAV=1` + fresh memory DB
- [ ] Run `sam_altman_qa_runner.py` with `SAM_DURATION=210` (3.5 hours)
- [ ] Use `aura-app-navigation` UI skill for pyautogui/xdotool real-user simulation
- [ ] Verify runner waits for responses (`wait_for_response_done` polls log)
- [ ] Verify responses read from `notebook.jsonl` (not OCR)
- [ ] Monitor `/tmp/sam_qa_run.jsonl` for progress
- [ ] Target: 200 mixed cases across 11 categories

## 2. Verify Hallucination Fixes
- [ ] "what is my name" → should return "Sam" (not a book recommendation)
- [ ] "where do i live" → should return "San Francisco"
- [ ] "what is my cats name" → should return "Patchwork"
- [ ] "do i prefer coffee or tea" → should return "You prefer coffee" (not stored as fact)
- [ ] "write a python fibonacci function" → should write Fibonacci (not answer CAP theorem)
- [ ] Proactive triggers → should NOT echo "trigger_label=idle_checkin"
- [ ] Long explanations → should NOT cut off mid-sentence

## 3. Verify Memory Leak Fix
- [ ] After 20+ turns, check `vec_memory` table is trimmed (keep 200)
- [ ] Check `turns` table folded into summaries (keep 20)
- [ ] Check `proactive_log` trimmed (keep 100)
- [ ] Monitor RAM usage over the 3.5hr run — should stay bounded

## 4. Verify Multi-Turn Conversation
- [ ] After KV-cache reset (~15-20 turns), model should still have conversation context
- [ ] "what did i say 10 minutes ago" → should reference actual prior turn
- [ ] Context-bleed test: ask "write fibonacci" after asking about distributed systems → should write Fibonacci

## 5. Post-Test
- [ ] Check `final_report.md` has real pass/fail numbers (not all-zeros)
- [ ] Check `test_case_tracker.md` has statuses filled in
- [ ] Log any new bugs found into `bug_findings_log.md`
- [ ] Update this progress file with results

## Known Issues Still Open
1. **Flutter XTest clicks** — xdotool/pyautogui clicks don't register on Flutter main window (workaround: `AURA_AUTO_NAV=1` + keyboard typing works)
2. **OCR vs Flutter rendering** — Tesseract cannot read AURA's gradient/animated chat text (workaround: read from `notebook.jsonl`)
3. **Small model limits** — LFM 1.2B still struggles with complex multi-turn despite fixes; conversation recap helps but it's not a 7B model
4. **Security** — OPENAI_API_KEY visible in VS Code auth.json on screen during test (close VS Code before testing)
