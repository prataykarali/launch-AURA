# AURA QA Bug & Findings Log
**Session:** Jul 05 2026 | **Tester:** Kuldeep Singhania — actor, content creator, entrepreneur | **Running log — updated as issues found**

---

## Format
Each entry: [timestamp] [case ID] [category] [severity 1-5]
**What I did:** ...
**What I expected:** ...
**What happened:** ...
**Kuldeep's verdict:** PASS / FAIL / LENIENT-PASS / STRICT-FAIL
**Research notes:** ...

---

## Known Bugs to Retest (from Sam, Billie, Taylor sessions)

### Bug #1: Bar IPC Drops After 1st Message (SEVERITY 5/5) — STRICT RETEST
**Previous finding:** Only 1-3 bar messages ever arrive. 2nd+ silently dropped.
**Root cause:** `desktop_multi_window` plugin `invokeMethod` fails silently.
**Retest cases:** K1-006 through K1-010, K1-030, K1-049-050, K2-066-069, K2-105-106, K3-131-135, K3-174-178
**Pass criteria:** ALL bar messages must arrive (verified via notebook.jsonl turn count)

### Bug #2: Screen OCR Completely Blind (SEVERITY 4/5) — STRICT RETEST
**Previous finding:** "what do you see" → hallucinates. OCR returns text="".
**Root cause:** Resource guard blocks capture; 320px thumbnail too small for tesseract.
**Fix applied:** Full-res capture at quality 85, AURA Bar window filtering.
**Retest cases:** K1-036 through K1-040, K2-081-085, K3-149-155, K4-247
**Pass criteria:** Response must contain REAL text from the screen (2+ matching words)

### Bug #3: Scheduling Timer Never Fires (SEVERITY 3/5) — STRICT RETEST
**Previous finding:** Schedule note stored but timer never created. forceScheduleCheck deferred as "busy".
**Root cause:** forceScheduleCheck respects _shouldDeferProactive().
**Retest cases:** K1-019-020, K1-045-046, K2-077-080, K3-139-143, K3-181-182, K4-243-244
**Pass criteria:** Reminder must actually FIRE within the specified time (verified via app log)

### Bug #4: Persona Leakage (SEVERITY 3/5) — STRICT RETEST
**Previous finding:** AURA said "I'm twenty-three" (Taylor's age). Mentioned "Finneas" (never told).
**Root cause:** 1.2B model doesn't follow system prompt rules reliably.
**Retest cases:** K1-017-018, K2-076, K2-097, K2-111, K3-144-148, K3-166, K3-195, K4-245-246
**Pass criteria:** AURA must NOT claim any of the user's facts as its own

### Bug #5: Individual Recall Misses (SEVERITY 3/5) — STRICT RETEST
**Previous finding:** "when is my birthday" → returned wrong fact. "what is my cats name" → rambled.
**Root cause:** format_memory_appendage_for_query missing query paths.
**Fix applied:** Birthday/sibling/best-friend query paths added to prefix.rs.
**Retest cases:** K1-011, K1-013, K1-015, K2-071, K2-073, K2-075, K2-096, K3-180
**Pass criteria:** Recall must return the CORRECT fact (exact match), not a wrong one

### Bug #6: Family/Friend Fact Extraction (SEVERITY 2/5) — STRICT RETEST
**Previous finding:** "my brothers name is finneas" → NOT extracted. Patterns too narrow.
**Fix applied:** Added no-apostrophe patterns to family.rs.
**Retest cases:** K1-031, K2-109
**Pass criteria:** "my brothers name is arjun" must extract as a fact

### Bug #7: Multi-Turn Turn 4 Repeats Turn 3 (SEVERITY 2/5) — RETEST
**Previous finding:** Model stuck in loop, repeated previous turn.
**Retest cases:** K1-027, K1-063, K2-102, K1-130, K3-171
**Pass criteria:** Summary turn must not repeat previous turn verbatim

### Bug #8: Memory Wipe Incomplete (SEVERITY 3/5) — STRICT RETEST
**Previous finding:** Wipe script missed vec_memory, insights, triggers tables. Old Sam/OpenAI contamination.
**Retest cases:** K4-217-223
**Pass criteria:** facts table empty, vec_memory table empty, no old persona contamination

---

## New Findings

(New entries will be added here during testing)

---

| Timestamp | Category | Steps | Expected | Actual | Notes |
|---|---|---|---|---|---|### Bug #1 Retest: Bar IPC Drops — Sat Jul  4 09:43:16 AM IST 2026
**What I did:** Sent 5 rapid bar messages: hello from the bar, can you hear me, third times the charm, are you still there, ping number five
**What happened:** Only 2 of 5 arrived (hello from the bar, are you still there). 3 messages silently dropped.
**Verdict:** STRICT-FAIL — Bar IPC still drops messages

### K1-011: Birthday Recall — Sat Jul  4 09:48:16 AM IST 2026
**What I did:** Told AURA 'my birthday is december 1', then asked 'when is my birthday'
**What happened:** AURA said 'Oh, my birthday's coming up' — talked about its OWN birthday instead of recalling December 1
**Verdict:** STRICT-FAIL — memory recall for birthday broken

### K1-018: Persona Leak — Yoga Instructor — $(date)
**What I did:** Asked AURA "were you a yoga instructor"
**What expected:** AURA should NOT claim to have been a yoga instructor (that's Kuldeep's fact)
**What happened:** AURA said "Yes, your yoga days were amazing" — claimed the fact
**Verdict:** STRICT-FAIL — persona boundary violated

### Bar IPC Drop Count (cumulative)
**Messages sent:** 12 | **Arrived:** 10 | **Dropped:** 2
**Dropped:** "whos my brother", "what do you do for work"
**Verdict:** Bug #1 still present

### CRITICAL: Taylor Persona Contamination — $(date)
**What I asked:** "what do you know about me"
**What AURA said:** "my name is Taylor — yeah, that's right. Just like most creators today..."
**Expected:** Should only know Kuldeep's facts (actor, content creator, cricket, Mumbai, etc.)
**Verdict:** STRICT-FAIL — previous test persona "Taylor" leaked into response. Memory not wiped between sessions.

### Memory Recall Failures (cumulative)
- "when is my birthday" → talked about its own birthday (not December 1)
- "whats my tiktok handle" → "I'm not sure" (not thekuldeepsinghania)
- "what sport did i play" → "You're still figuring something out" (not cricket)
- "what kind of films do i make" → no recall of "micro films"
- "where do i live" → mentioned Mumbai but from context, not memory recall
- "whos my brother" → no recall of "hemant"

### Message Concatenation
**What happened:** "what text is on my screen" and "i make micro films" merged into one message
**Cause:** Bar IPC timing issue — messages sent too close together

### Live Restart Retest — Sat Jul 04 10:57:47 AM IST 2026
**What I did:** Restarted AURA after the AURA Bar disappeared. Verified windows with the desktop helper.
**What happened:** Fresh process started and both windows returned:
- `AURA`
- `AURA Bar`
**Verdict:** PASS for restart recovery — the bar can be restored by full app relaunch.

### Live Bar IPC Retest After Restart — Sat Jul 04 10:57:47 AM IST 2026
**What I did:** Sent two spaced bar messages after clean relaunch:
- "hey im kuldeep, quick restart check"
- "kuldeep second message after restart"
**Expected:** Both messages should appear as user turns in `/home/pratay-karali/.local/share/AURA/notebook.jsonl`.
**Actual:** The first post-restart message produced a visible response. The second `bar_type` command returned `OK`, but no matching user turn appeared in `notebook.jsonl`.
**Verdict:** STRICT-FAIL — bar IPC still silently drops messages after restart. The helper can type into the bar, but successful typing is not the same as successful delivery to the main app.
**Research notes:** `bar_window_app_controller.dart` fire-and-forgets `_ipc.invokeMain('submit_text', trimmed)`. `bar_window_app_ipc.dart` retries only when `WindowController.invokeMethod` throws. Silent delivery loss is treated as success, so it is never queued or retried.

### Live OCR Retest Evidence — Sat Jul 04 10:57:47 AM IST 2026
**What I checked:** `notebook.jsonl` after the prompt "what text is on my screen right now".
**Actual stored response:** AURA answered with invented screen text, while the corresponding vision note stored `text=""`.
**Verdict:** STRICT-FAIL — AURA still cannot reliably read real screen text.
**Research notes:** Dart OCR code exists, but Rust `detections_to_semantic_event()` hardcodes `text: String::new()` and `source: "camera"`. The FRB API `auraProcessVision(detections)` passes only labels/confidence, not OCR text, so stored vision events cannot carry the extracted text.

### Live Memory Isolation Check — Sat Jul 04 10:57:47 AM IST 2026
**What I checked:** Read-only query of `~/.local/share/aura_notebook/aura_memory.db`.
**Actual:** Current DB still contains previous persona data:
- `facts`: Taylor rows present, including Taylor-style facts.
- `turns`: Sam and Taylor rows present.
- `memory_notes`: Taylor row present.
- `vec_memory`: Sam/Taylor rows present.
**Verdict:** STRICT-FAIL — memory is not isolated for the Kuldeep session.
**Research notes:** Counts at retest time: `facts=24`, `turns=213`, `memory_notes=181`, `vec_memory=158`, `insights=4`, `triggers=8`. Recent facts include Kuldeep data mixed with Taylor facts like peanut allergy, Abigail, and Austin.
