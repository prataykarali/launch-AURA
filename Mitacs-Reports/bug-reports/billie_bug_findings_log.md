# AURA QA Bug & Findings Log
**Session:** Jul 02 2026 | **Tester:** Billie Eilish persona | **Running log — updated as issues found**

---

## Format
Each entry: [timestamp] [case ID] [category] [severity 1-5] 
**What I did:** ...  
**What I expected:** ...  
**What happened:** ...  
**Billie's reaction:** ...  
**Research notes:** ...

---

(Log entries appear below as testing progresses)

---

## Bugs Found (pre-populated from Sam Altman session — retest after fixes)

### Bug #1: Screen Vision — OCR Pipeline (FIXED)
**Status:** Retest needed — OCR pipeline now added with tesseract
**Sam's finding:** AURA could not read any screen content (websites, PDFs, code)
**Fix applied:** Added `_extractScreenText()` to vision analysis, Wayland support via `grim`, unique temp files
**Retest case:** B2-001 through B2-055 (VS Code + OCR categories)

### Bug #2: Bar Input Death on Relaunch (FIXED)
**Status:** Retest needed — stale window cleanup + double-focus added
**Sam's finding:** After killing and relaunching AURA, bar stopped accepting input
**Fix applied:** `_cleanupStaleBarWindows()` before creating new bar, double `focus()` in `showAndFocus()`
**Retest case:** B4-012 (stress test: kill and relaunch)

### Bug #3: Messages Silently Dropped (FIXED)
**Status:** Retest needed — FIFO queue replaces single-slot overwrite
**Sam's finding:** Messages sent during processing were silently lost
**Fix applied:** `List<_QueuedPrompt> _promptQueue` with max 5 entries, FIFO dequeue
**Retest case:** B4-011 (stress test: send 3 messages rapidly)

### Bug #4: Dynamic Response Sizing Backwards (FIXED)
**Status:** Retest needed — truncation direction fixed, length hints added
**Sam's finding:** "2+2" got 35 words, complex questions got nonsense
**Fix applied:** `_streamUpdate` truncates from END (keeps beginning), `_buildPromptWithLengthHint()`
**Retest case:** B3-021, B3-022 (dynamic sizing tests)

### Bug #5: Memory Extraction Too Literal (FIXED)
**Status:** Retest needed — idiom detection + multi-fact extraction added
**Sam's finding:** "explain like I'm 5" stored as "User's age is 5"; multi-fact sentences only extracted first
**Fix applied:** Idiom rejection in `extract_age()`, subject inheritance in `split_into_clauses()`
**Retest case:** B3-041, B3-042 (idiom test), B1-023 (multi-fact)

### Bug #6: Scheduling Doesn't Schedule (FIXED)
**Status:** Retest needed — time parsing improved
**Sam's finding:** Reminders acknowledged but never fired
**Fix applied:** `_parseScheduleTimeHint()` now handles "in an hour", "at 5:30", "noon", "midnight", "tomorrow morning"
**Retest case:** B3-003 through B3-020 (scheduling tests)

### Bug #7: Proactive Response Contamination (FIXED)
**Status:** Retest needed — greeting templates isolated from context
**Sam's finding:** Morning greeting said "check your script" instead of "good morning"
**Fix applied:** Clock greetings use clean templates without conversation context, memory limited to 200 chars
**Retest case:** B3-001, B3-002, B3-005 (proactivity tests)

### Bug #8: TTS Queue Blocks Input (FIXED)
**Status:** Retest needed — TTS is now non-blocking
**Sam's finding:** Bar became unresponsive during TTS playback (20-30s)
**Fix applied:** Android speak is `unawaited()`, word-based duration estimation, timer IDs to prevent stale callbacks
**Retest case:** B4-013 (stress test: ask during TTS)

---

## New Findings

(New entries will be added here during testing)
