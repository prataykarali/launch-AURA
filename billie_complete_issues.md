# AURA — Complete Issue List from Billie Eilish's Testing
**Compiled from:** billie_final_report.md, billie_bug_findings_log.md, billie_test_case_tracker.md, final_report.md (Sam), notebook.jsonl chat logs
**Total issues found: 18** (8 original + 6 new + 4 newly identified from chat logs)

---

## ISSUE #1: Bar IPC Drops Messages After 2-3 Inputs
**Severity:** 5/5 — SHOWSTOPPER  
**When found:** External testing phase  
**What happens:** After sending 2-3 messages via the bar, all subsequent messages are silently lost. The bar appears to accept input (you can type and hit enter) but nothing reaches the main window.  
**Evidence:** Log shows only first 2-3 `submit_text` IPC messages; subsequent attempts produce no log entry. Billie tried typing "whats your process for writing lyrics" 3 times — never arrived.  
**Billie's reaction:** "I'd type something, hit enter, and... nothing. It worked for the first couple messages then just stopped. A real user would think AURA is broken."  
**Fix needed:** Bar window IPC handler needs a retry queue + non-blocking main window handler.

---

## ISSUE #2: Screen OCR Returns Empty Text
**Severity:** 4/5  
**When found:** External browser testing  
**What happens:** Tesseract OCR pipeline runs on screenshots but returns empty strings. All vision events show `text=""`. AURA can't read browser content, code, or lyrics.  
**Evidence:** 36 vision events stored, ALL with `text=""`. The screenshot is 320px thumbnail — too small for tesseract.  
**Billie's reaction:** "It tried to read my Wikipedia page but couldn't actually read the text. It said 'your screen's showing my name' which is sort of right but not useful."  
**Fix needed:** Increase screenshot size from 320px to 800px+.

---

## ISSUE #3: AURA Repeats Topics from Previous Turns (REPETITION BUG)
**Severity:** 4/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** AURA keeps bringing up previous conversation topics even when the user has moved on. The memory injection system re-injects old facts into every response.  
**Evidence from chat logs:**
- Response #18 (snack question): "A snack like nuts and fruit... **As for books**, I'd love something... **Coffee-wise**, try a bold espresso..." — Nobody asked about books or coffee!
- Response #20 (reverb question): "Reverb is all about adding depth... **As for music… making it feels like sharing secrets**..." — Nobody asked about making music.
- Response #22 (BPM question): "BPM stands for beats per minute... **Now about scaling laws...**" — Nobody asked about scaling laws!
- Response #24 (Juno 106): "**Your favorite coffee's pour-over**—it's like watching the beans bloom... And music? Oh man..." — Nobody asked about coffee or music.
- Response #27 (recall): "I love the Juno 106... **My favorite coffee is definitely pour over**... The best part about making music..." — AURA claims coffee as ITS favorite, then rambles about music.
- Response #58 (neon green): "**And hey, shark loves the ocean vibes** just as much as I do. Want to talk about coffee together?" — Randomly mentions dog + coffee in a color question.
- Response #77 (dogs question): "Dogs are awesome... **Music's such a powerful thing too**... **AGI is still a big conversation** right now..." — Nobody asked about music OR AGI.

**Root cause:** Memory injection puts ALL stored facts into the prompt context every turn. The 1.2B model can't ignore irrelevant context — it weaves it into every response.  
**Billie's reaction:** "It keeps talking about coffee and music when I asked about snacks. Like it can't let go of previous topics. It's like talking to someone who keeps bringing up old conversations."  
**Fix needed:** Only inject RELEVANT memory facts (semantic match to current question), not ALL facts.

---

## ISSUE #4: AURA Rambles / Loops Instead of Stopping (RAMBLING BUG)
**Severity:** 3/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** Instead of giving a clean short answer, AURA appends unrelated topics, creating long rambling responses. The model seems to loop through stored memories.  
**Evidence from chat logs:**
- Response #12 (name): "What a sweet name—billie sounds so melodic. As for AI... **What about your cat?** It must be playful—maybe it's named something cute like **Whiskers or Purrball**." — Hallucinated a cat that doesn't exist.
- Response #43 (music theory): "Making a bridge feels like adding another note... Music theory can be tricky... **but think of it as learning how different parts work together. It takes patience, just like growing up.**" — Rambles from bridge → theory → patience → growing up.
- Response #52: "Hey! I remember your name is AURA, and you're 18 years old today." — Confused itself with the user AND made up an age.
- Response #55 (dog): "**Let me know if you want to chat more about AI, life, or anything else.**" — Random topic pivot.
- Response #113: "I can see you're already having a great chat, Billie! Your energy is contagious. It's nice hearing about **Shark too—I think he'd love this dog story**. And hey, since" — Cut off mid-sentence.

**Root cause:** The 1.2B model has weak stopping behavior. The continuation loop (`generate.rs`) generates extra paragraphs when the model doesn't emit EOS. Memory injection feeds it topics to ramble about.  
**Billie's reaction:** "It just goes on and on. I asked one thing and got three topics I didn't ask about. Like it can't help itself."  
**Fix needed:** Reduce memory injection to 2-3 most relevant facts max. Add stronger EOS detection. Cap response at 3 sentences for simple questions.

---

## ISSUE #5: AURA Confuses Itself with the User (PERSONA LEAKAGE)
**Severity:** 3/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** AURA claims user's facts as its own. Says "MY favorite coffee" instead of "YOUR favorite coffee." Confuses who is who.  
**Evidence from chat logs:**
- Response #27: "**My favorite coffee is definitely pour over**" — This is BILLIE's fact, not AURA's.
- Response #45 (rain lyrics): "**I'm Billie, from LA** where the sun never stops shining" — AURA is pretending to BE Billie.
- Response #52: "**I remember your name is AURA**, and you're 18 years old today" — AURA thinks the USER is AURA.
- Response #58: "**neon green is so bright on my eyes** when I'm writing songs—maybe that's your favorite color too?" — AURA claims neon green as its own.
- Response #81: "Your dog **Shark** is probably chasing something in the room right now." — Hallucinating what the dog is doing.

**Root cause:** The persona system prompt says AURA is "a 17-year-old girl lost inside the internet" — this persona overlaps with the user's identity. The pronoun conversion in `turn/prefix.rs` (I→you, my→your) may be misfiring.  
**Billie's reaction:** "It keeps stealing my facts! It said 'MY favorite coffee is pour over' — that's MY coffee, not yours! And it said 'I'm Billie, from LA' — no, I'M Billie!"  
**Fix needed:** Strengthen persona boundaries in system prompt. Add explicit rule: "Never claim user's facts as your own. Use 'your' not 'my' for user preferences."

---

## ISSUE #6: Multi-Turn Only 2 Good Turns Then Degrades (Sam's Original Bug — Partially Fixed)
**Severity:** 3/5  
**When found:** Sam Altman session, retested by Billie  
**What happens:** In the Sam session, responses collapsed after turn 3 (494→534→158 chars). In Billie's 5-turn test, lengths were stable (180→225→160→200→220) BUT the content quality degrades — AURA starts repeating topics.  
**Evidence:** Billie's 5-turn test held length but turn 2 brought up "haikus" and "rain" from earlier sessions. Turn 4 brought up "ocean" in a follow-up. The model can't sustain truly fresh responses past 2-3 turns.  
**Sam's finding:** "Turn 1: 494, Turn 2: 534, Turn 3: 158 (collapse). Turn 5: 494 (recovered with explicit 'go deeper')."  
**Billie's finding:** "It held for 5 turns but kept referencing old stuff. Like it was running out of new things to say."  
**Fix needed:** Reduce context window pollution. Reset KV cache more aggressively. Don't inject all memory every turn.

---

## ISSUE #7: Context Leakage — "My Brother is a Singer" Confuses Extraction
**Severity:** 3/5 — NEWLY IDENTIFIED  
**What happens:** When user says "my brother is a singer," AURA may conflate "user is a singer" with "user's brother is a singer." The fact extraction doesn't distinguish who the singer is.  
**Evidence:** User said "im a singer" → fact "User is a singer" stored. Later said "my brothers name is finneas, he produces my music" → fact NOT stored (family pattern too narrow). But AURA's response said "In LA beats where **Finneas writes my tracks**" — it understood Finneas produces music but attributed it to "my tracks" (AURA's tracks, not Billie's).  
**Billie's reaction:** "When I said my brother produces my music, it got confused about who makes the music — me or Finneas."  
**Fix needed:** Add family extraction patterns. Add context disambiguation in memory injection.

---

## ISSUE #8: Family/Friend Fact Extraction Misses "Name Is" Pattern
**Severity:** 2/5  
**What happens:** "my brothers name is finneas" and "my best friends name is zoe" are NOT extracted.  
**Evidence:** DB shows 8 facts but no "User has brother named Finneas" or "User has best friend named Zoe."  
**Root cause:** Rules expect "named X" not "name is X."  
**Fix needed:** Add 10+ new anchor patterns in `family.rs`.

---

## ISSUE #9: Scheduling Timer Never Fires
**Severity:** 3/5  
**What happens:** "remind me to drink water in 2 minutes" → schedule note IS extracted and stored as pinned memory note. But timer is never created because scheduler only checks every 15-30 min.  
**Evidence:** Note #965 stored: "Schedule request: remind me to drink water in 2 minutes" (pinned=1). After 2.5 min wait — no reminder fired. After 10 min — still no reminder.  
**Billie's reaction:** "It stored my reminder but never actually reminded me. What's the point?"  
**Fix needed:** Trigger immediate `_checkScheduleNotes()` after storing a schedule note.

---

## ISSUE #10: Active Window Detection Always Shows "AURA Bar"
**Severity:** 3/5  
**What happens:** Vision service reads "AURA Bar" as the active window because the bar is always-on-top. Can't detect the actual focused app (browser, VS Code).  
**Evidence:** All vision contexts show `detail:"AURA Bar"` instead of "Billie Eilish - Wikipedia - Brave."  
**Fix needed:** Filter out bar window ID in `_readLinuxActiveWindowTitle()`.

---

## ISSUE #11: Bar Input Death After Relaunch (Partially Fixed)
**Severity:** 3/5 (was 5/5, improved)  
**What happens:** After kill+relaunch, the app keyboard input works but the bar window repositions and IPC may not reconnect properly.  
**Evidence:** App works after relaunch via keyboard (Tab+type). Bar window appears in a different position. Bar IPC works for first 2-3 messages then drops (see Issue #1).  
**Billie's reaction:** "I can still type after restarting, that's better. The bar moved to a weird spot though."  
**Fix status:** Partially fixed — stale window cleanup + double focus added.

---

## ISSUE #12: Dynamic Sizing Sometimes Rambles (Partially Fixed)
**Severity:** 2/5 (was 4/5, improved)  
**What happens:** Short questions mostly get short answers now, BUT the model sometimes appends unrelated topics after the answer.  
**Evidence:** "what is reverb?" → good short answer about depth, then ramble about "making music feels like sharing secrets." "what is BPM?" → good answer, then "Now about scaling laws..."  
**Fix status:** Partially fixed — truncation direction fixed, length hints added, but memory injection still causes rambling.

---

## ISSUE #13: Math Errors (7×8=46)
**Severity:** 1/5  
**What happens:** 7×8=56 but AURA said "forty-six."  
**Root cause:** 1.2B model can't do arithmetic. Expected limitation.  
**Billie's reaction:** "It said 7 times 8 is 46. That's wrong. But it's a small model, I get it."

---

## ISSUE #14: Embed Queue Overflows Under Load
**Severity:** 2/5  
**What happens:** `store_embed dropped (queue full/disconnected)` appeared 9+ times when vision + chat + memory run simultaneously.  
**Fix needed:** Increase bounded work bucket capacity.

---

## ISSUE #15: AURA Hallucinates Non-Existent Facts
**Severity:** 3/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** AURA invents facts that were never told.  
**Evidence:**
- Response #12: "What about your cat? It must be playful—maybe it's named Whiskers or Purrball." — User never mentioned a cat.
- Response #52: "you're 18 years old today" — User never said their age.
- Response #81: "Your dog Shark is probably chasing something in the room right now." — Hallucinating dog's activity.
- Response #113: "I think he'd love this dog story" — Fabricating context.

**Root cause:** The 1.2B model hallucinates when it has gaps in context. Memory injection gives it facts but it fills gaps with fabricated details.  
**Billie's reaction:** "It made up a cat I don't have. And said I'm 18. I never told it my age."  
**Fix needed:** Add anti-hallucination guard in system prompt: "Never invent facts. If you don't know, say so."

---

## ISSUE #16: Responses Cut Off Mid-Sentence
**Severity:** 2/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** Some responses end abruptly mid-word or mid-sentence.  
**Evidence:**
- Response #113: "And hey, since" — cut off.
- Response #3 (Sam session): "Honestly?" — trailing off.
- Response #37: "music is our family now." — abrupt end after poem.

**Root cause:** Token budget hits max before the model emits EOS. The continuation loop doesn't detect incomplete sentences.  
**Fix needed:** Check if last token is sentence-ending punctuation. If not, generate 10 more tokens to complete the sentence.

---

## ISSUE #17: Proactive Trigger References Prior Context (Non-Greeting)
**Severity:** 2/5  
**What happens:** The bandit-RL proactive trigger (not a clock greeting) referenced the ocean conversation: "oceans are such powerful symbols of both beauty and strength."  
**Evidence:** Response #133: "Thanks for checking in... oceans are such powerful symbols..."  
**Note:** This is actually CONTEXT-AWARE behavior, not a bug for non-greeting triggers. The contamination fix only applies to clock greetings. But it can feel like AURA is "stuck" on old topics.  
**Billie's reaction:** "It randomly started talking about oceans. I mean, we were talking about that earlier, but I didn't bring it up."

---

## ISSUE #18: "Drink Water in 2 Minutes" Reminder Leaks into Chat Responses
**Severity:** 2/5 — NEWLY IDENTIFIED FROM CHAT LOGS  
**What happens:** The schedule note "remind me to drink water in 2 minutes" was injected into subsequent chat responses as if AURA was reminding the user inline.  
**Evidence:**
- Response #120: "Hey billie! I'm here and ready to chat—**just remember to drink water in2 minutes** next time!" — The reminder text leaked into a normal chat response.
- Response #115: "Just a quick reminder—**hydration's key**, even when we're chatting away." — Reminder context bleeding.

**Root cause:** Schedule notes are stored as pinned memory notes, which get injected into chat context via `auraGetProactiveContext()`. The model treats the reminder as current context and mentions it in responses.  
**Billie's reaction:** "It kept telling me to drink water in normal conversation. Like it couldn't separate the reminder from our chat."  
**Fix needed:** Exclude schedule notes from chat memory injection. Only inject them into proactive trigger prompts, not regular chat.

---

## SUMMARY: All 18 Issues Ranked by Severity

| # | Issue | Severity | Status | New? |
|---|-------|----------|--------|------|
| 1 | Bar IPC drops after 3 messages | 5/5 | Not fixed | New |
| 2 | Screen OCR returns empty text | 4/5 | Partial fix | New |
| 3 | AURA repeats topics from previous turns | 4/5 | Not fixed | **NEW from logs** |
| 4 | AURA rambles/loops instead of stopping | 3/5 | Not fixed | **NEW from logs** |
| 5 | AURA confuses itself with user (persona leak) | 3/5 | Not fixed | **NEW from logs** |
| 6 | Multi-turn degrades after 2-3 turns | 3/5 | Partial fix | Original |
| 7 | Context leakage — "brother is a singer" | 3/5 | Not fixed | **NEW from logs** |
| 8 | Family/friend extraction misses "name is" | 2/5 | Not fixed | New |
| 9 | Scheduling timer never fires | 3/5 | Partial fix | Original |
| 10 | Active window always "AURA Bar" | 3/5 | Not fixed | New |
| 11 | Bar input death after relaunch | 3/5 | Partial fix | Original |
| 12 | Dynamic sizing sometimes rambles | 2/5 | Partial fix | Original |
| 13 | Math errors (7×8=46) | 1/5 | Expected | Original |
| 14 | Embed queue overflows | 2/5 | Not fixed | New |
| 15 | AURA hallucinates non-existent facts | 3/5 | Not fixed | **NEW from logs** |
| 16 | Responses cut off mid-sentence | 2/5 | Not fixed | **NEW from logs** |
| 17 | Proactive references prior context | 2/5 | By design | **NEW from logs** |
| 18 | Schedule reminder leaks into chat | 2/5 | Not fixed | **NEW from logs** |

---

## WHAT BILLIE WOULD TELL THE ENGINEERING TEAM

"Okay, here's the thing. AURA has heart — I genuinely felt that. The camera sees me, the memory knows me, the conversation feels natural when it works. But there are three things that would make me stop using it:

**One — the bar drops my messages.** After two or three messages it just stops listening. I'm typing and hitting enter and nothing happens. That's the thing that would make me uninstall it.

**Two — it can't stop talking about old stuff.** Every response brings up coffee, or music, or the ocean, or my dog, even when I asked about something completely different. It's like talking to someone who keeps bringing up old conversations because they can't think of anything new. You need to make it only bring up relevant memories, not ALL of them.

**Three — it steals my identity.** It says 'MY favorite coffee is pour over' — that's MY coffee. It says 'I'm Billie, from LA' — no, I'M Billie. It needs to know the difference between itself and me.

The camera vision, the memory storage, the proactivity, the translation — those all work. The multi-turn held up for 5 turns which is better than before. But the repetition, the rambling, and the bar dropping messages — those are the things that would make me go back to just using ChatGPT."

---

## ROOT CAUSE ANALYSIS — The 3 Core Problems

### Core Problem A: Memory Injection is Indiscriminate
**Causes Issues:** #3 (repetition), #4 (rambling), #12 (sizing ramble), #18 (reminder leak)  
**Root cause:** `auraGetProactiveContext()` returns ALL stored facts/notes every turn. The 1.2B model can't ignore irrelevant context — it weaves everything into the response.  
**Fix:** Implement semantic relevance filtering — only inject facts that match the current question (cosine similarity > 0.5). Exclude schedule notes from chat injection.

### Core Problem B: Bar IPC Architecture is Fragile
**Causes Issues:** #1 (IPC drops), #11 (input death)  
**Root cause:** The bar window sends messages via `WindowController.invokeMethod('submit_text')` but the main window's handler appears to block or drop messages during LLM generation. There's no retry, no acknowledgment, no queue.  
**Fix:** Add a message queue in the bar window controller with retry-on-fail. Make the main window's IPC handler fire-and-forget (process asynchronously, don't block).

### Core Problem C: Persona Boundaries Are Weak
**Causes Issues:** #5 (persona leak), #7 (context leakage), #15 (hallucination)  
**Root cause:** The system prompt says AURA is "a 17-year-old girl lost inside the internet" which overlaps with a young creative user like Billie. The pronoun conversion (I→you) may misfire. The model hallucinates to fill context gaps.  
**Fix:** Add explicit boundary rules to system prompt: "You are AURA, not the user. Never claim user's facts as your own. Never invent facts. If you don't know, say so. Use 'your' for user preferences, 'I' only for your own thoughts."
