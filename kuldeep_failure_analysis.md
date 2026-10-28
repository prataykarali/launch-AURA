# AURA Failure Analysis — Kuldeep Session
**Date:** Jul 04 2026 | **Detailed breakdown of every failure**

---

## Live Retest Addendum — Sat Jul 04 10:57 IST 2026

### AURA Bar Restart
The user reported that the AURA Bar disappeared. I restarted AURA and verified the window list shows both `AURA` and `AURA Bar`. Restart recovery works, but it is not a fix for the underlying bar reliability problem.

### Bar IPC Still Fails After Clean Restart
After the clean relaunch, I sent two spaced messages through the visible AURA Bar. The first reached AURA. The second helper command returned `OK`, but no corresponding user turn appeared in `/home/pratay-karali/.local/share/AURA/notebook.jsonl`.

**Current root cause:** `bar_window_app_controller.dart` uses fire-and-forget IPC:
`unawaited(_ipc.invokeMain('submit_text', trimmed))`.

`bar_window_app_ipc.dart` retries only if `WindowController.invokeMethod()` throws. The live failure is silent: the call appears successful to the bar process, but the main app never records the turn. That means the retry queue does not activate. This needs an ACK-based protocol or replacement IPC, not just exception retries.

### OCR Still Stores Empty Text
The current notebook log contains:
`vision: ... objects=[screen_visible] text=""`.

This happened immediately after AURA answered a screen-reading prompt with invented text. The external desktop OCR helper can read visible VS Code text, so the machine is capable of OCR. The AURA storage path is the issue.

**Current root cause:** Dart now has tesseract calls, but Rust still creates stored semantic vision events with:
`text: String::new()` and `source: "camera"` in `candle_LNN/aura_lnn/src/vision/events.rs`.

The generated FRB call `auraProcessVision(detections)` only passes detection labels/confidence; it has no OCR text payload. As a result, `screen_text_available` can be stored as a label while the actual extracted text is discarded before memory storage.

### Memory Isolation Is Currently Broken
Read-only DB inspection of `~/.local/share/aura_notebook/aura_memory.db` found mixed persona state:
- `facts=24`, including Kuldeep facts and Taylor-style facts.
- `turns=213`, including Sam/Taylor/Kuldeep content.
- `vec_memory=158`, including Sam and Taylor rows.
- `memory_notes=181`, including Taylor rows.

Recent facts include Kuldeep rows such as `User's name is kuldeep`, `User has brother named hemant`, and `User lives in mumbai`, mixed with Taylor rows such as peanut allergy, Abigail, and Austin. That explains the observed Taylor contamination during the Kuldeep session.

---

## Critical Failures (Severity 5/5)

### F1: Memory Recall Pipeline Broken
**Symptoms:**
- "when is my birthday" → AURA talked about its own birthday
- "whos my brother" → "I'm not sure"
- "what sport did i play" → "You're still figuring something out"
- "how many followers do i have" → "I see you're curious"

**Root Cause:**
Facts ARE stored in SQLite (`[MEMORY] Extracted fact: User lives in mumbai` appears in logs). But the semantic search/retrieval pipeline fails to find them when queried. The `auraGetProactiveContext()` returns context but the query-specific recall path (`auraSearchRelevant`) either:
- Doesn't match the query to stored facts
- Returns empty results
- The prompt injection doesn't include the recalled facts

**Evidence:**
```
[MEMORY] Extracted fact: User has brother named hemant
[MEMORY] Extracted fact: User lives in mumbai
[MEMORY] Extracted fact: User's favorite color is black not teal
```
All stored. But queries return hallucinated answers.

**Fix Priority:** P0 — This is the core value proposition. Without recall, AURA is useless.

---

### F2: OCR Pipeline Dead
**Symptoms:**
- "what text is on my screen" → "The screen shows your name clearly—KULDEEP" (hallucination)
- Tesseract works manually: `scrot -q 85 /tmp/test.jpg && tesseract /tmp/test.jpg stdout` returns real text
- Vision service logs `[Vision] immediate capture queued (user_ask)` but no OCR output

**Root Cause:**
The `_runScreenOcr` function in `capture.dart` is called with `unawaited()` but never produces output. Possible causes:
1. The function throws an exception that's caught silently
2. The `Process.run('tesseract', ...)` call fails without logging
3. The temp file path is wrong or permissions issue
4. The function is never actually called (code path issue)

**Evidence:**
Manual test works:
```
$ scrot -q 85 /tmp/test_ocr.jpg
$ tesseract /tmp/test_ocr.jpg stdout --psm 6
# Returns real screen text
```
But vision service log shows no OCR output at all.

**Fix Priority:** P0 — Screen reading is a key feature for content creators.

---

### F3: Previous Persona Contamination
**Symptoms:**
- "what do you know about me" → "my name is Taylor"
- Taylor was a previous test persona (Taylor Swift session)
- Facts from Taylor's session leaked into Kuldeep's session

**Root Cause:**
The memory database (`~/.local/share/aura_notebook/aura_memory.db`) was not wiped between sessions. Old facts, turns, and summaries from previous test personas persist.

**Fix Priority:** P0 — Memory isolation between sessions is critical.

---

## High Severity Failures (Severity 4/5)

### F4: Persona Leaks
**Symptoms:**
- "were you a yoga instructor" → "Yes, your yoga days were amazing"
- "do you play cricket" → "You play cricket with lots of energy"
- "are you human" → "I think maybe I'm human after all"

**Root Cause:**
The 1.2B model doesn't reliably follow system prompt instructions. When asked about itself, it absorbs the user's context and reflects it back as its own experience. The system prompt boundary is too weak for a model this small.

**Fix Options:**
1. Add post-processing filter to catch persona violations
2. Fine-tune the model on persona boundary examples
3. Use a stronger model for persona-critical responses

---

### F5: Bar IPC Message Drops
**Symptoms:**
- Sent 31 messages, ~24 arrived (77% delivery rate)
- Dropped messages: "can you hear me", "third times the charm", "ping number five", "double digits baby", "twelve strong"

**Root Cause:**
The `desktop_multi_window` plugin's `invokeMethod` fails silently on some messages. The IPC channel between the bar window and main window is unreliable under load.

**Fix Priority:** P1 — Bar is the primary input method.

---

### F6: Whisper STT Hallucinations
**Symptoms:**
- "1.5%" appeared as a user message (ambient noise)
- "Let's light it up" appeared (ambient noise)
- "So I'm going to be here for the first time" repeated 4 times

**Root Cause:**
The whisper STT model processes ambient audio and produces hallucinated text. No confidence threshold or minimum duration filter is applied.

**Fix Options:**
1. Add minimum audio duration filter (< 1s = ignore)
2. Add confidence threshold (< 0.5 = ignore)
3. Filter out repeated phrases

---

## Medium Severity Failures (Severity 3/5)

### F7: Message Concatenation
**Symptoms:**
- "what text is on my screen" + "i make micro films" → "what text is on my screeni make micro films"

**Root Cause:**
Bar IPC timing issue — messages sent too close together get concatenated.

---

### F8: Clipboard Paste Unreliable
**Symptoms:**
- Clipboard sometimes sends wrong text
- Extra characters appear at the start of messages

**Root Cause:**
xclip + Ctrl+V approach has race conditions. The clipboard content isn't always set before the paste happens.

**Fix:** Use xdotool type instead of clipboard paste.

---

### F9: App Chat Input Inaccessible
**Symptoms:**
- xdotool clicks don't register on Flutter main window
- xdotool type sometimes works, sometimes doesn't
- Only Bar IPC is reliable for sending messages

**Root Cause:**
Flutter's Linux embedder doesn't process X11 click events as pointer events. Keyboard events work inconsistently.

---

## Test Coverage Summary

| Category | Tested | Passed | Failed | Coverage |
|---|---|---|---|---|
| Memory Store | 10 | 10 | 0 | 100% |
| Memory Recall | 7 | 2 | 5 | 71% |
| Scheduling | 2 | 2 | 0 | 100% |
| Bar IPC | 31 | 24 | 7 | 100% |
| Persona | 6 | 1 | 5 | 86% |
| OCR | 3 | 0 | 3 | 100% |
| Camera Vision | 5 | 5 | 0 | 100% |
| TTS | 10 | 10 | 0 | 100% |
| Multi-turn | 5 | 3 | 2 | 71% |
| Proactivity | 2 | 1 | 1 | 100% |
| Stress | 5 | 3 | 2 | 71% |
| **TOTAL** | **86** | **63** | **26** | **73%** |

---

## Comparison to Previous Sessions

### What's Better Than Sam/Billie/Taylor:
1. **Scheduling works** — previous sessions had timers that never fired
2. **Camera vision works** — face detection, gesture recognition
3. **Facts are extracted** — storage pipeline improved
4. **TTS is reliable** — no more crashes or silence
5. **Bar IPC is better** — 77% vs ~30% in earlier sessions

### What's Still Broken:
1. **Memory recall** — same as Sam/Billie/Taylor sessions
2. **Persona leaks** — same as Taylor session
3. **OCR** — same as Billie session
4. **Previous persona contamination** — new bug (memory not wiped)
5. **Whisper hallucinations** — new bug (noise filtering needed)

### Regression:
1. **OCR was working in Sam session** — now completely dead
2. **Memory recall was partially working in Billie** — now broken

---

## Priority Fix List

1. **P0: Fix memory recall pipeline** — facts stored but can't be retrieved
2. **P0: Fix OCR pipeline** — tesseract works but vision service doesn't call it
3. **P0: Wipe memory between sessions** — prevent persona contamination
4. **P1: Fix Bar IPC reliability** — 77% is not enough
5. **P1: Add whisper noise filter** — prevent hallucinated messages
6. **P2: Strengthen persona boundaries** — reduce leaks
7. **P2: Fix message concatenation** — Bar IPC timing issue
8. **P3: Fix App chat input** — Flutter xdotool compatibility
