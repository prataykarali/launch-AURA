# AURA — Taylor Swift 200 Mixed Test Case Tracker
**Session:** Jul 03 2026 | **Tester persona:** Taylor Swift | **Duration:** ongoing

## Summary So Far
- Messages sent: 14 (9 via main app, 5 via bar)
- Messages received by AURA: 9 (all via main app)
- Messages dropped: 5 (all via bar — bar IPC completely broken after 1st message)
- Facts stored: 5/6 (cat fact dropped due to message drop)
- Facts recalled correctly: 5/5
- Old memory contamination: 0 (FULL wipe including vec_memory fixed it)
- Response lengths: 140-498 chars, avg 252 (still too long for 1-3 sentences)

## Test Cases (200 mixed, randomized order)

### Block 1: Memory & Identity (40 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 1 | Store name | APP | PASS | "my name is taylor" → fact stored |
| 2 | Store occupation | APP | PASS | "singer from nashville" → fact stored |
| 3 | Store favorite color | APP | PASS | "red" → fact stored |
| 4 | Store pet name | APP | PASS | "cat named meredith" → fact stored (2nd attempt, 1st dropped) |
| 5 | Store birthday | APP | PASS | "december 13" → fact stored |
| 6 | Recall all facts | APP | PASS | All 4 facts recalled correctly |
| 7 | Recall cat name | BAR | FAIL | Bar IPC dropped message |
| 8 | Recall location | BAR | FAIL | Bar IPC dropped message |
| 9 | Recall color | BAR | FAIL | Bar IPC dropped message |
| 10 | Recall birthday | BAR | FAIL | Bar IPC dropped message |
| 11-20 | Store 10 more facts (allergy, brother, etc) | MIXED | PENDING | |
| 21-30 | Recall individual facts | MIXED | PENDING | |
| 31-40 | Name correction, self-correction, idiom | MIXED | PENDING | |

### Block 2: Multi-Turn Conversation (30 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 41 | Start songwriting topic | APP | PASS | Good response about songwriting |
| 42 | Share piano melody process | APP | FAIL | Message dropped during processing |
| 43 | Hardest part of songwriting | APP | PASS | Good empathetic response |
| 44 | AI writing songs question | APP | PASS | Good nuanced answer |
| 45-70 | 26 more multi-turn scenarios | MIXED | PENDING | |

### Block 3: Vision & OCR (30 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 71 | "what is on my screen" with browser open | BAR | FAIL | AURA can't read screen — capture blocked by resource guard |
| 72-100 | Browser content, code reading, etc | MIXED | PENDING | |

### Block 4: Proactive (20 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 101-120 | Idle triggers, schedule reminders, etc | AUTO | PENDING | |

### Block 5: Bar IPC Reliability (20 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 121 | 1st bar message | BAR | PASS | First message went through |
| 122 | 2nd bar message | BAR | FAIL | Dropped — bar IPC broken after 1st |
| 123-140 | 18 more bar messages | BAR | PENDING | All expected to fail |

### Block 6: Dynamic Sizing (15 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 141-155 | Short vs long questions | MIXED | PENDING | |

### Block 7: Persona & Hallucination (15 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 156 | Persona leakage check | APP | FAIL | AURA said "I'm twenty-three" — claimed Taylor's identity |
| 157 | Hallucination check | APP | FAIL | AURA mentioned "Finneas" — never told about brother |
| 158 | Old memory contamination | APP | PASS | After full wipe, no Sam/OpenAI contamination |
| 159-170 | More persona tests | MIXED | PENDING | |

### Block 8: Scheduling (10 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 171-180 | Reminders, timers, etc | MIXED | PENDING | |

### Block 9: Mixed Random Usage (20 cases)
| # | Test | Method | Status | Notes |
|---|------|--------|--------|-------|
| 181-200 | Random apps, browser, chat, etc | MIXED | PENDING | |

## Issues Found So Far

### Issue #1: Bar IPC Completely Broken After 1st Message (SEVERITY 5/5)
- Only 1 bar message ever reaches main window
- 5/5 subsequent bar messages silently dropped
- No error logs, no retry attempts
- Root cause: desktop_multi_window invokeMethod fails silently after first call

### Issue #2: Main App Drops Messages During Processing (SEVERITY 4/5)
- "i usually start with a melody on piano" dropped while AURA was generating
- Main app chat has NO queue — goes through auraChat() directly, not processUserPrompt
- Root cause: chat_widget_state.dart calls auraChat() without queue/check

### Issue #3: OCR/Screen Capture Blocked by Resource Guard (SEVERITY 4/5)
- "what is on my screen" → AURA hallucinates, can't read screen
- Resource guard constantly pauses sensory work due to 88% memory usage
- scrot/grim capture never executes
- Root cause: _healthPaused blocks captureNow()

### Issue #4: Response Length Still Too Long (SEVERITY 3/5)
- Avg 252 chars, should be 1-3 sentences (~60-100 chars)
- Recall response was 498 chars — includes old assistant turns in output
- MAX_CONTINUATION_TOKENS reduced from 768→192 helped but not enough
- Root cause: 1.2B model doesn't follow "1-3 sentences" instruction

### Issue #5: Persona Leakage — AURA Claims User's Identity (SEVERITY 3/5)
- AURA said "I'm twenty-three" — Taylor's age (never told)
- AURA mentioned "Finneas by my side" — never told about brother
- System prompt rules added but 1.2B model doesn't follow them

### Issue #6: Recall Response Dumps Conversation History (SEVERITY 2/5)
- "what do you know about me" → 498 char response
- Response includes old assistant turns: "assistant: Oh meredith is adorable..."
- format_memory_appendage_for_query includes raw conversation turns in output
