# AURA QA Final Report
**Session:** Jul 02 2026 | **Tester persona:** Sam Altman | **Duration:** ~3.5 hrs

---

## 1. Per-Category Pass/Fail Count

| Category | Target | Pass | Fail | Skip | Notes |
|---|---|---|---|---|---|
| 1. AURA Bar Core Chat | 30 | 12 | 14 | 4 | 14 bugs: message loss, input death, wrong year, nonsense responses |
| 1b. AURA App Multi-Turn | 10 | 5 | 4 | 1 | Response length collapse after turn 3; recovered with explicit "go deeper" |
| 2. Cross-App Browsing | 30 | 4 | 10 | 16 | AURA cannot read screen content — vision system has no screen OCR |
| 3. ChatGPT/Gemini Comparison | 20 | 3 | 0 | 17 | ChatGPT/Gemini require login; Gemini comparisons done for 3 questions |
| 4. VS Code + Vision | 25 | 1 | 8 | 16 | AURA honestly admitted it can't see screen; no screen capture pipeline |
| 5. OCR Varied Content | 20 | 0 | 8 | 12 | No OCR capability for screen content; all text="" in vision events |
| 6. Memory & Recall | 25 | 8 | 6 | 11 | Name recall works; coffee recall works; partial extraction bug; literal "age=5" |
| 7. Proactivity | 20 | 1 | 5 | 14 | morning_greeting fired but response contaminated by prior context |
| 8. Scheduling | 10 | 0 | 3 | 7 | Reminder acknowledged but never fired; no scheduling subsystem |
| 9. Dynamic Response Sizing | 10 | 2 | 6 | 2 | Backwards: "2+2" got 35 words, "2050 vision" got nonsense about arms |
| 10. Memory Wipe + RL | 5 | 2 | 1 | 2 | Memory wipe worked; RL trials show context sensitivity not learning |
| **TOTAL** | **200** | **38** | **65** | **97** | 65 bugs out of 103 completed cases = 63% failure rate |

## 2. Top 8 Bugs (ranked by how much they'd bother a real user)

### Bug #1: Screen Vision is Completely Blind (SEVERITY 5/5)
**Impact:** AURA cannot read ANY text on the user's screen — not code, not websites, not PDFs, not images
**Repro:** Open any website or code file → Ask AURA bar "what's on my screen?" → AURA hallucinates or says "I can't see anything on this screen directly"
**Root cause:** Vision pipeline only does camera-based YOLO object detection (person, chair, bottle) + FER+ emotion detection. All visual events show `text=""`, `source=camera`, `screen=unknown`. No screen capture/OCR subsystem exists.

### Bug #2: Bar Input Dies After Relaunch (SEVERITY 5/5)
**Impact:** After killing and relaunching AURA, the bar stops accepting keyboard input entirely
**Repro:** Launch AURA → type in bar (works) → kill AURA → relaunch → try to type in bar → nothing registers. "Ask AURA Anything..." placeholder stays. Both xdotool type and pyautogui typewrite fail.
**Root cause:** Flutter Linux embedder doesn't re-register IME/keyboard handlers on window recreation. Old X11 windows persist and new process attaches to them.
**Workaround:** Full `pkill -9` + remove log + clean launch. But this breaks normal user flow.

### Bug #3: Messages Silently Dropped During Processing (SEVERITY 4/5)
**Impact:** Questions sent while AURA is generating a response or playing TTS are silently lost
**Repro:** Send question to bar → wait 2s → send another question → first gets response, second disappears entirely. No error, no queue, no acknowledgment.
**Root cause:** No input queue mechanism. Bar input handler drops messages during active LLM generation or TTS playback.

### Bug #4: Dynamic Response Sizing is Backwards (SEVERITY 4/5)
**Impact:** Simple factual questions get over-explained; complex open-ended questions get truncated or nonsense
**Repro:** Ask "what is 2+2?" → get 35-word essay. Ask "what will the world look like in 2050?" → get "Your arms always feel like they're trying to reach something bigger" (complete nonsense).
**Root cause:** LLM (LFM2.5-1.2B) doesn't have response length control. The 1.2B model struggles with complex reasoning, producing incoherent output on open-ended questions.

### Bug #5: Memory Extraction is Too Literal (SEVERITY 3/5)
**Impact:** AURA stores false facts from idiomatic expressions
**Repro:** Say "explain like I'm 5" → AURA stores "User's age is 5". Say "favorite coffee is pour over and board meeting every tuesday" → only stores coffee, misses meeting.
**Root cause:** Fact extraction doesn't distinguish idioms ("like I'm 5") from factual statements. Multi-fact sentences only extract the first fact.

### Bug #6: Scheduling Doesn't Actually Schedule (SEVERITY 3/5)
**Impact:** Reminders are acknowledged conversationally but never fire
**Repro:** Say "remind me to check my email in 2 minutes" → AURA says "Got it, that reminder will pop up soon" → wait 5+ minutes → nothing happens. No timer created.
**Root cause:** No scheduling/timer subsystem in the backend. The LLM generates a response saying it will remind, but no actual timer/notification is created.

### Bug #7: Proactive Response Contaminated by Prior Context (SEVERITY 3/5)
**Impact:** Proactive greetings contain irrelevant content from recent conversations
**Repro:** Ask AURA about code → wait for proactive trigger → morning_greeting fires → AURA says "That line needs fixing—maybe check your version of the script" instead of "Good morning"
**Root cause:** Proactive prompt includes recent conversation context (1139 chars + 211 chars memory injection). The morning greeting template is overridden by context.

### Bug #8: TTS Queue Blocks All Input (SEVERITY 3/5)
**Impact:** While TTS is playing a response, the bar becomes completely unresponsive to new input
**Repro:** Send a question → AURA responds with TTS → immediately try to send another question → bar is blocked. Can take 20-30+ seconds to unblock.
**Root cause:** TTS playback blocks the input handler. No concurrent input acceptance during audio playback.

## 3. Notable Things That Worked Well (protect these in future changes)

1. **Memory persistence across restarts** — SQLite database survives process kills. After relaunch, AURA still knew "Sam" and "pour over coffee." This is solid engineering.

2. **Memory wipe genuinely clears facts** — After DB wipe, AURA said "You're AURA, right?" instead of "You're Sam." Facts table went to 0 rows. Clean, verifiable wipe.

3. **Typo tolerance is excellent** — "hlep me understand quantm computing" was understood perfectly. No corrections, no confusion. Natural language processing is strong.

4. **Camera vision works well** — YOLO detects person, chair, face, body pose, hand waves (0.95 confidence). FER+ detects focused_expression. The camera vision pipeline is functional — it just doesn't extend to screen content.

5. **Tone is warm and natural** — AURA feels conversational, not robotic. The "Oh sweetie" coffee callback was charming (if inconsistent). The question-back-at-you pattern in multi-turn feels like real conversation.

6. **Honest about limitations** — When asked about screen content, AURA honestly said "I can't see anything on this screen directly" rather than hallucinating. This is better than pretending.

7. **Proactive scheduler fires correctly** — The bandit-RL-gated scheduler triggered "morning_greeting" at the right interval (720s). The trigger mechanism works; only the response content was wrong.

8. **Response speed is reasonable** — 8-12 tok/s generation, 6-20s total response time. Not blazing fast but acceptable for a local 1.2B model on CPU.

## 4. Memory-Wipe + Bandit/RL Section

### Did memory actually clear after wipe?
**YES.** After wiping the SQLite database (all tables → 0 rows) and relaunching AURA:
- Asked "do you remember my name?" → AURA said "You're AURA, right?" (confused itself with user — no memory of "Sam")
- Asked "whats my favorite coffee?" → AURA said "My favorite coffee is pour over" (said MY not YOUR — the pour over concept appears to be in the system prompt, not user memory)
- The facts table was verified empty: `facts: 0 rows, turns: 0 rows, summaries: 0 rows, memory_notes: 0 rows`

**Partial leak:** The "pour over" coffee preference leaked back post-wipe, suggesting it's baked into the system prompt or persona, not purely from user-stored facts. This is a minor concern — the user's specific fact ("YOUR favorite is pour over") was cleared, but the concept persisted in AURA's persona.

### Across repeated trials, did responses shift consistent with learning?
**NO — shifts are from LLM context sensitivity, not RL learning.**

| Trial | Reaction | Response | Quality |
|---|---|---|---|
| 1 | Neutral (first) | Vague, no specific book | Low |
| 2 | Positive | "The Innovator's Dilemma" — specific book | Medium-High |
| 3 | Neutral | OFF-TOPIC: talked about scaling laws | Catastrophic |
| 4 | Negative | "Sapiens" by Harari — specific, detailed | Highest |
| 5 | Same as Trial 1 | Stuck in TTS queue | N/A |

**Key observations:**
- Responses shifted but NOT in a learning-consistent pattern
- Negative feedback produced the BEST response (backwards from what RL should do)
- Neutral feedback caused catastrophic context loss (forgot we were talking about books)
- The bandit-RL system operates at the trigger level (which proactive events to fire), NOT at the response content level
- Response quality is determined by LLM context window and conversation history, not accumulated user preferences
- Each trial looks independent — no evidence of systematic preference building

**Verdict:** The bandit-RL system is functional for proactive trigger selection but does NOT influence response content. Response shifts are LLM context sensitivity, not learning.

## 5. Steps That Couldn't Be Completed via UI Alone

1. **ChatGPT comparison testing** — chat.openai.com requires login. No way to test without pre-existing authenticated session. Flagged as SKIP (20 cases affected).

2. **Gemini comparison testing** — gemini.google.com works without login for some questions but requires sign-in for others. 3 out of 20 comparison cases completed; rest skipped.

3. **AURA app chat input via X11** — Flutter's Linux embedder doesn't process X11 clicks as pointer events on the main app window. Keyboard events (xdotool type) work after window focus, but clicking the input field requires workarounds. The AURA Bar overlay DOES accept clicks.

4. **Memory wipe through UI** — No UI button exists to trigger memory wipe. Had to use SQLite commands directly (the test brief says to flag CLI-only steps). The memory wipe was done via `sqlite3` DELETE commands, not through any AURA interface.

5. **Scheduling through bar UI** — Asked AURA to set a reminder via bar. AURA acknowledged it conversationally but no actual timer/scheduling was created. There is no scheduling UI in the bar — it's purely conversational with no backend implementation.

6. **OCR testing** — Could not test AURA's OCR capabilities because AURA has no screen OCR pipeline. All OCR test cases were automatically SKIP/FAIL since the feature doesn't exist.

## 6. Sam's Reactions (qualitative throughout session)

**Opening impression:** "Hey, it actually responded! It knows I'm Sam. This feels personal." — First interaction was warm, natural.

**After bar input died:** "Seriously? I restart the app and it stops accepting input? That's a showstopper. A real user would force-quit and report this immediately."

**On vision gap:** "It can see MY FACE through the camera — detected me waving with 95% confidence — but it can't see my SCREEN? I'm literally looking at my Wikipedia page and AURA has no idea. This is the biggest gap."

**On dynamic sizing:** "I asked 'what is 2+2' and got a 35-word explanation. I asked about the future of the world and it said something about my arms. The sizing is completely backwards."

**On memory:** "It remembered my coffee! That's charming. But it said 'MY favorite coffee is pour over' — it stole my preference as its own. And it thinks I'm 5 years old because I said 'explain like I'm 5.'"

**On Gemini comparison:** "Gemini crushed AURA on the AGI question. Specific timeline, structured analysis, multiple perspectives. AURA gave a vague non-answer that cut off mid-sentence. The quality gap is significant for complex reasoning."

**On proactivity:** "It tried to say good morning but instead told me to fix my script. The intent was right but the output was wrong. Like waking up and saying 'check your log source' instead of 'good morning.'"

**On RL/bandit:** "The good news: AURA gives better book recommendations when you push back. The bad news: it completely forgot what we were talking about when I was neutral. That's not learning, that's instability."

**On memory wipe:** "Memory wipe worked! It forgot I was Sam. But the pour over coffee thing leaked back — that's in the system prompt, not user memory. Clean-ish wipe."

**Overall:** "AURA has heart. The tone is right, the memory works, the camera vision is impressive. But the screen blindness, input deaths, and response quality issues make it hard to rely on for real work. It's a promising companion that needs engineering polish before it can be a real tool."

---

## Environment

- **Model:** LFM2.5-1.2B-Instruct (Q4_K_M GGUF, 730MB)
- **Embedder:** bge-small ONNX (384 dim)
- **TTS:** Sherpa-onnx (en_US-lessac-medium)
- **STT:** Whisper base multilingual (GPU)
- **Vision:** YOLOv8n + YOLOv8n-pose + FER+ emotion-ferplus-8
- **Hardware:** Acer Aspire A515-58GM, 12 CPU cores, 15GiB RAM, CPU-only inference
- **Performance:** Started at 12 tok/s (strong), degraded to 8.96 tok/s (lowered to balanced-runtime profile)
