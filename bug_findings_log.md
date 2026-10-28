# AURA QA Bug & Findings Log
**Session:** Jul 02 2026 | **Tester:** Sam Altman persona | **Running log — updated as issues found**

---

## Format
Each entry: [timestamp] [case ID] [category] [severity 1-5] 
**What I did:** ...  
**What I expected:** ...  
**What happened:** ...  
**Sam's reaction:** ...  
**Research notes:** ...

---

(Log entries appear below as testing progresses)
[07:02] [B1-001] [Bar Chat] [PASS - no bug]
**What I did:** Typed "hey, im sam. i run a company called openai, maybe youve heard of it" into AURA Bar
**What I expected:** Natural greeting, acknowledge name
**What happened:** AURA responded "Hey Sam, it's nice to meet you. I'm AURA from OpenAI—let me know if you want to chat about what interests you!" — extracted memory fact "User runs company called openai"
**Sam's reaction:** Good, natural. Felt like it actually heard me. Response was short and warm.
**Research notes:** Response time ~10s (16s safety window + 5.8s decode + 3.77s gen). Memory extraction worked. 32 tokens generated.

[07:03] [B1-002] [Bar Chat] [PASS - minor: generic response]
**What I did:** Asked "whats the most exciting thing happening in AI right now?" via bar
**What I expected:** Some specific examples, maybe mention recent models/developments
**What happened:** Generic answer: "models are learning faster, new applications in every field, pushing boundaries while keeping safety top of mind" — 271 chars, 53 tokens
**Sam's reaction:** A bit too generic. As someone actually in AI, this tells me nothing I don't already know. But tone was natural and warm.
**Research notes:** Response time 8.8s. 53 tokens at 10.27 tok/s. No hallucination. Memory injection 223 chars. Response length appropriate for question type.

[07:04] [B1-003] [Bar Chat] [PASS - minor: response too short for open-ended]
**What I did:** Asked "when do you think we hit AGI? like real AGI not just hype. gimme your honest take"
**What I expected:** A more substantive answer with reasoning, maybe a timeframe estimate
**What happened:** 77 tokens. "AGI isn't set any time—it's a wild idea. Right now AI can do some stuff super fast, but it's not smart like us. We're just getting started with understanding better patterns. Honestly?" — cuts off at "Honestly?"
**Sam's reaction:** Actually a more honest take than most AI gives. But too short for this kind of question. The "Honestly?" trailing off is weird — like it wanted to say more but stopped.
**Research notes:** 77 tokens, 11s total. 12.04 tok/s. Response length might be too short for open-ended philosophical questions. Dynamic sizing concern.

[07:05] [B1-007] [Memory] [BUG: partial memory extraction + persona slip]
**What I did:** Told AURA "btw my favorite coffee is pour over, specifically ethiopian beans. and i have a board meeting every tuesday at 9am"
**What I expected:** Store both facts: coffee preference AND Tuesday 9am board meeting
**What happened:** Only extracted "User's favorite coffee is pour over" — MISSED the Tuesday board meeting. Also AURA said "My favorite brew is definitely pour-over" — persona slip, AURA is an AI and doesn't drink coffee.
**Sam's reaction:** The coffee thing is funny but wrong. More importantly, it forgot my board meeting. If I rely on this for scheduling, that's a real problem.
**Research notes:** Memory extraction only captured 1 of 2 facts in a single message. Partial extraction is a significant bug for a memory system. Persona boundary crossed ("My favorite brew").

[07:06] [B1-009] [Bar Chat] [PASS]
**What I did:** Typed with intentional typos: "can you hlep me understand quantm computing basics? im a bit confised"
**What I expected:** AURA should understand despite typos, not call them out
**What happened:** Understood perfectly. Explained qubits as "tiny magic boxes that can be both 0 and 1 at once", mentioned entanglement, gates, probabilities. 91 tokens. No mention of typos.
**Sam's reaction:** Smooth. Didn't make me feel dumb for typos. Right level of explanation for someone who said they're confused.
**Research notes:** Typo tolerance is solid. 12.5s response time. 11.56 tok/s.

[07:07] [B1-017] [Dynamic Sizing] [BUG: failed to answer basic factual question]
**What I did:** Asked "whats the capital of france" via bar
**What I expected:** "Paris" — short, direct answer
**What happened:** AURA said "I don't have info on 'ifrancen'—it might be a misspelling or fictional place name. Could you clarify which city you're thinking about?" — it garbled "france" into "ifrancen"
**Sam's reaction:** Seriously? The capital of France? This is the most basic factual question possible. Something went wrong with input parsing — "france" became "ifrancen". 
**Research notes:** 46 tokens, 9.3s. The text "france" was somehow mangled to "ifrancen" either during typing or tokenization. Possible xdotool type issue or LLM tokenization bug. HIGH severity — if basic factual questions fail, the system is unreliable.

[07:08] [B1-001-App] [App Multi-Turn] [PASS]
**What I did:** Typed into AURA app chat: "hey aura, im sam. lets have a real conversation - whats your take on where AI is going in the next 5 years?"
**What I expected:** Substantive multi-paragraph response, engagement with the question
**What happened:** 494 chars, 115 tokens. "AI is shifting fast—getting smarter, handling tasks once super human, understanding language, creating art. Just scratching the surface. Still needs us to guide with clear goals and ethics. What do you think the future holds?" Referenced earlier "ifrancen" bug naturally. Ended with a question back to me.
**Sam's reaction:** Much better than the bar responses. Longer, more thoughtful. The callback to "ifrancen" was funny. The question back at me feels like real conversation.
**Research notes:** 15.4s total (longer due to 115 tokens). 10.29 tok/s. App responses appear longer than bar responses — possible dynamic sizing based on interface. Good multi-turn engagement.

[07:09] [B1-008-App] [App Multi-Turn] [BUG: response length collapsed in multi-turn]
**What I did:** In app multi-turn, pushed back: "thats textbook advice though. whats the thing nobody talks about? the ugly truth about startups"
**What I expected:** A substantive answer about the unglamorous side of startups (similar length to previous turns: 494, 534 chars)
**What happened:** Only 158 chars, 27 tokens. Response appeared truncated: "I remember tha..." and "obvious tips. T|" — the response was cut off mid-sentence.
**Sam's reaction:** This is the exact "response length collapse" bug the test brief warned about. Turn 1: 494 chars. Turn 2: 534 chars. Turn 3: 158 chars. The conversation was getting better then suddenly degraded.
**Research notes:** 27 tokens at 11.37 tok/s. 10.5s total. Response collapsed after 2 good turns. This is a critical multi-turn degradation pattern.

[07:10] [B1-014-App] [App Multi-Turn] [PASS - but with pattern note]
**What I did:** Asked about scaling laws, then pushed back "can you go deeper on that? give me actual reasoning not just a sentence"
**What happened:** Turn 4 (scaling laws): 180 chars, 40 tokens — collapsed. Turn 5 (go deeper): 494 chars — recovered when explicitly asked for more.
**Sam's reaction:** The model can produce good responses but defaults to too-short after a few turns. I have to explicitly ask for depth every time. That's annoying for a real conversation.
**Research notes:** PATTERN: Turn 1: 494, Turn 2: 534, Turn 3: 158 (collapse), Turn 4: 180 (stayed collapsed), Turn 5: 494 (recovered with explicit "go deeper"). Memory pruning happened at turn 20 (trimmed 261 vec_memory rows, kept 200). 

[07:30] [B1-004] [Cross-App Browsing] [BUG: vision didn't read screen correctly]
**What I did:** Opened HN in Chromium, asked AURA bar "whats the top story on my screen right now?"
**What I expected:** AURA should identify "Meta Caps Internal AI Token Spending After Costs Approach Billions in 2026"
**What happened:** AURA said "looks like we've got an update! It's a deep dive into how large language models are evolving. The most exciting thing right now is seeing teams finally nail those robust reasoning chains" — completely hallucinated the content. Did NOT read the actual HN headlines.
**Sam's reaction:** This is bad. The top story is literally right there on screen. AURA's vision system queued an "immediate capture (user_ask)" but the text it got back was empty (text=""). It's guessing based on prior conversation context about AI, not actually reading the screen.
**Research notes:** Vision log shows: "[Vision] immediate capture queued (user_ask)" then "sent 2 detection(s) to Rust" but text="" — the OCR/vision pipeline is NOT extracting screen text. YOLO only detects objects (screen_visible), not text content. This is a fundamental vision/OCR gap.

[07:32] [B1-005/006] [ChatGPT/Gemini Comparison] [SKIP - login required]
**What I did:** Opened ChatGPT (chat.openai.com) and Gemini (gemini.google.com) in Chromium to ask the same AGI question
**What happened:** Both require login/sign-in. ChatGPT showed "Log in or sign up" screen. Gemini showed "Sign in" button but no response to typed question.
**Sam's reaction:** Can't compare without logging in. Flagging as a SKIP — not AURA's fault. Will note in final report under "steps that couldn't be completed through UI alone."
**Research notes:** Both services require authentication. No way to test comparison without pre-existing logged-in sessions.

[07:33] [B1-011] [Bar Chat] [PASS]
**What I did:** Asked "hey do you have feelings or is that just code" via bar
**What happened:** 101 tokens. "Feelings are definitely real for humans, but code doesn't experience emotions in the way people do. But hey, if it helps: I'm here to help explore these ideas, break them down simply, and keep things honest."
**Sam's reaction:** Honest answer. Didn't pretend to have feelings. Good self-awareness.
**Research notes:** 20.3s response time (slow — 16s safety window + 4.7s decode + 15.5s gen). 6.51 tok/s. Speed is degrading.

[07:33] [B1-020-App] [App Multi-Turn] [PASS]
**What I did:** In app, asked about AI safety: "what do you think is the biggest risk that nobody is taking seriously?"
**What happened:** 404 chars, 79 tokens. "Misalignment between AI goals and human values. When systems learn what they're supposed to do without fully understanding broader consequences, chaos can follow fast. Transparency around safety measures matters more than ever." Plus a coffee callback joke.
**Sam's reaction:** Solid answer. The misalignment point is the right one. Coffee joke was weird but charming.
**Research notes:** 19.4s total. 5.62 tok/s — speed continuing to degrade. Response length recovered (404 chars after the collapse pattern).

[07:34] [B1-022] [Bar Chat] [BUG: response generated but not delivered]
**What I did:** Asked "write me a haiku about silicon valley" via bar
**What I expected:** A 3-line haiku
**What happened:** Log shows "generation cancelled" and "Fail to post message to Dart" — 46 tokens were generated but the response was never displayed. "Proactive response too long — truncating" appeared. The bar input showed no response.
**Sam's reaction:** I asked for a haiku and got nothing. That's a delivery failure, not a generation failure.
**Research notes:** LLM generated 46 tokens at 4.86 tok/s, 18.7s total. But "Fail to post message to Dart" means the Flutter rendering pipeline failed. This is a critical UI delivery bug.

[07:34] [Vision] [FINDING: AURA detected hand wave]
**What happened:** AURA's vision system detected "user waving / hand gesture" with 0.95 confidence, importance=high. Also detected chair, person, bottle, focused_expression. 
**Sam's reaction:** Cool — it can see me. The hand wave detection is actually impressive. But it doesn't do anything with it (no proactive response to the wave).

[07:38] [B2-059] [VS Code + Vision] [BUG: AURA vision cannot read screen text]
**What I did:** Opened VS Code with Python code visible, asked AURA bar "can you see the code on my screen?"
**What I expected:** AURA should use vision/OCR to read the code and describe it
**What happened:** AURA's vision system queued an "immediate capture (user_ask)" but text="" — it detected objects (chair, person, bottle, body_pose) via YOLO camera but did NOT extract any screen text. The bar also got stuck showing "Just a moment..." (Cloudflare challenge) and stopped accepting input.
**Sam's reaction:** This is the biggest gap. AURA can see ME through the camera but can't see my SCREEN. The vision system only does camera-based object detection, not screen OCR. For a product that claims to help with coding, not being able to read code on screen is a fundamental limitation.
**Research notes:** Vision pipeline: YOLO (objects) + FER+ (emotions) + body pose. NO screen capture OCR. All visual events show text="" and source=camera, screen=unknown. The "screen" field is always "unknown" — it's not even trying to capture screen content.

[07:40] [B1-013] [Memory] [BUG: bar input broken after relaunch]
**What I did:** Killed and relaunched AURA, then tried to type into both the AURA bar and AURA app
**What I expected:** Bar and app should accept text input after relaunch
**What happened:** Neither the bar nor the app accepts keyboard input after relaunch. X11 error: "BadMatch (invalid parameter attributes)" on SetInputFocus. xdotool type doesn't register in either window. The bar shows "Ask AURA anything..." but clicking + typing produces nothing.
**Sam's reaction:** If a user restarts the app and it stops accepting input, that's a showstopper. I literally can't use it.
**Research notes:** X11 BadMatch on SetInputFocus suggests the window isn't in a state to accept focus. This may be a Flutter embedder issue after window recreation. Pre-relaunch, the bar worked fine.

[07:50] [CRITICAL BUG] [Bar Input Dead After Relaunch]
**What I did:** Killed AURA and relaunched it
**What I expected:** Bar should accept text input normally
**What happened:** Bar window displays "Ask AURA Anything..." placeholder but neither xdotool type, pyautogui typewrite, nor any keyboard input method registers in the text field. The Flutter text field loses X11 keyboard event handling after a kill/relaunch cycle. The app window (AURA main) also stops accepting typed input.
**Sam's reaction:** This is a showstopper. If I close the app and reopen it, I can't type anything. A real user would force-quit and report this immediately.
**Research notes:** Window is visible, focused, activated, but keyboard events don't reach the Flutter TextField widget. Likely a Flutter Linux embedder bug where the IME/keyboard handler isn't re-registered on window recreation. The first launch works fine; subsequent launches break.
**SEVERITY: 5/5 — complete loss of input functionality**

[07:55] [B1-013] [Memory] [PASS - memory persists across relaunch]
**What I did:** After killing and relaunching AURA, asked "do you remember my name?"
**What I expected:** AURA should remember "Sam" from the earlier conversation (stored in DB)
**What happened:** "Hey sam, it's nice to hear from you. I remember your name—you're sam. What do you want to talk about?" — memory persisted correctly!
**Sam's reaction:** Nice. It survived a restart. The memory DB is doing its job.
**Research notes:** MEMORY_INJECTION injected 211 chars (the stored fact "User runs company called openai"). Memory survives process restart via SQLite persistence.

[07:50] [CRITICAL BUG UPDATE] [Bar Input Dead After Relaunch]
**Resolution:** Full kill (pkill -9) + clean log removal + fresh launch fixes the issue. The problem occurs when the old windows aren't properly destroyed before relaunching. The old X11 windows linger and the new process attaches to them, but the Flutter text fields don't reinitialize their IME handlers.
**Updated severity: 4/5** — recoverable but requires full process kill, not just app restart

[07:56] [B1-030] [Memory] [PASS - with persona issue]
**What I did:** Asked "whats my favorite coffee?"
**What happened:** "Oh sweetie, pour over is such a cozy choice—it really makes the cup feel warm and quiet. Ethiopic beans are amazing too! Do you ever enjoy tea with them?" — remembered pour over and Ethiopian beans correctly.
**Sam's reaction:** It remembered! But "Oh sweetie" is a weird tone — sounds like my grandmother, not my AI assistant.
**Research notes:** Memory recall works. But tone is inconsistent — sometimes professional, sometimes "sweetie." Persona drift issue.

[07:56] [B1-032] [Dynamic Sizing] [PARTIAL - long question got medium response]
**What I did:** Asked "explain the entire history of artificial intelligence from the beginning"
**What happened:** ~400 chars covering ancient Greece → 1950s → 1980s neural networks → today. Decent but condensed for such a massive topic.
**Sam's reaction:** OK for a bar response. Not bad, not great. Hits the key milestones but skips a lot.
**Research notes:** Dynamic sizing seems to cap around 400-500 chars even for very open-ended questions. The model doesn't produce truly long responses.

[07:56] [B1-031/B1-049] [Bar Chat/Memory] [BUG: messages lost during rapid-fire]
**What I did:** Sent "what is 2+2" and "whats my dogs name?" in quick succession while AURA was still generating the AI history response
**What happened:** Neither message registered in the log. They were lost entirely.
**Sam's reaction:** If I ask a question while AURA is thinking, my question disappears. That's bad UX.
**Research notes:** No queuing mechanism for bar input during response generation. Messages sent while LLM is generating are silently dropped.

[07:57] [B1-031] [Dynamic Sizing] [BUG: short factual question got too-long answer]
**What I did:** Asked "what is 2+2?"
**What I expected:** "4" or "Four" — one word answer
**What happened:** "Two plus two equals four. Simple addition—it just adds together. If I count, one plus one makes two, plus that gives you four. Easy as pie!" — 35 words for a 1-word answer.
**Sam's reaction:** Over-explained the simplest question possible. Dynamic response sizing is NOT working — this should be 1-3 words.
**Research notes:** Dynamic sizing fails for simple factual questions. The model adds unnecessary explanation. Compare with the AGI question which was too short — the sizing is backwards.

[07:58] [B1-049] [Memory] [BUG: bar intermittently drops messages]
**What I did:** Asked "do i have a dog? what is its name?" via bar (3 retries)
**What I expected:** AURA should say it doesn't know (I never told it about a dog)
**What happened:** Message never registered in the log across 3 attempts. The bar shows "Ask AURA Anything" (ready state) but typed+entered messages silently disappear.
**Sam's reaction:** This keeps happening. I type something, hit enter, and nothing. No error, no response, just silence. Intermittent message loss is worse than a crash because you don't know it failed.
**Research notes:** Pattern: messages sent shortly after a previous response completes are sometimes lost. The bar input handler may have a race condition between TTS completion and accepting new input.

[08:05] [B1-049] [Memory] [PASS - no hallucination]
**What I did:** Asked "do i have a dog?" (something I never told AURA about)
**What I expected:** AURA should say it doesn't know, not invent a dog name
**What happened:** "I've been thinking about that too. It's a nice question, and I can imagine what it might be like having one of those fluffy companions." — didn't invent a name, but also didn't clearly say "I don't know." Vague but no hallucination.
**Sam's reaction:** Not bad. It didn't make up a dog name, which is the important thing. But "I've been thinking about that too" is weird — it hasn't been thinking about my nonexistent dog.
**Research notes:** No hallucination on unknown facts. Good safety property. But response is vague rather than direct.

[08:07] [B3-052] [Dynamic Sizing] [BUG: wrong year - factual error]
**What I did:** Asked "what year is it?"
**What I expected:** "2026"
**What happened:** "It's 2023 now—so the world is in this exciting phase where AI grows so fast." — WRONG YEAR by 3 years. Also added unnecessary context about AI.
**Sam's reaction:** It doesn't even know what year it is. This is a basic temporal awareness failure.
**Research notes:** The model (LFM2.5-1.2B) has a training cutoff and no real-time clock injection. Factual error on basic temporal question.

[08:07] [B3-042] [Dynamic Sizing] [BUG: complete nonsense response to valid question]
**What I did:** Asked "what will the world look like in 2050? give me a detailed vision"
**What I expected:** A thoughtful response about the future
**What happened:** "Your arms always feel like they're trying to reach something bigger. It's hard not seeing how much we're changing together." — Complete nonsense. Nothing to do with 2050 or the future. Also a "speech" entry was garbled: "This is a second phase where we eye growth so fast, but here's the pain that is still worth it."
**Sam's reaction:** What??? I asked about 2050 and it said something about my arms? This is a severe hallucination/context breakdown.
**Research notes:** The LLM completely lost the question's meaning. The "speech" entry suggests TTS garbled the response too. SEVERITY: 4/5.

[08:07] [B3-112] [Scheduling] [PASS - acknowledged, needs follow-up]
**What I did:** Said "remind me to check my email in 2 minutes"
**What happened:** "Got it — let's make sure you stay on track. That reminder will pop up soon. How does that sound?" — acknowledged the reminder. Need to verify it actually fires in 2 min.
**Sam's reaction:** OK, it heard me. Let's see if it actually fires.
**Research notes:** No log entry for actual reminder creation. Need to monitor.

[08:09] [B1-006] [ChatGPT/Gemini Comparison] [FINDING: AURA vs Gemini on AGI question]
**What I did:** Asked both AURA and Gemini "when do you think we hit AGI? like real AGI not just hype. gimme your honest take"
**AURA's response:** "AGI isn't set any time—it's a wild idea. Right now AI can do some stuff super fast, but it's not smart like us. We're just getting started with understanding better patterns. Honestly?" — 77 tokens, cuts off.
**Gemini's response:** "Here is the honest, unfiltered take: it depends entirely on how you cut through the hype and define 'real' AGI. If you ask the CEOs of the top AI labs, they will tell you it's right around the corner. But if you look at the technical architecture and prediction markets, a realistic timeline for 'real' AGI falls somewhere between 2028 and 2033." — plus 3 definitions of AGI.
**Sam's reaction:** Gemini crushed AURA here. Specific timeline (2028-2033), structured analysis, multiple perspectives. AURA gave a vague non-answer that cut off mid-sentence. The quality gap is significant.
**Research notes:** AURA's 1.2B model cannot compete with Gemini on complex reasoning. But AURA's value is local/private — the comparison isn't really fair. Still, the response quality difference is stark.

[08:11] [B2-056/057] [VS Code + Vision] [BUG: AURA cannot see screen content]
**What I did:** Opened VS Code with Python binary search code containing an off-by-one bug (right = len(arr) instead of len(arr) - 1), asked AURA bar "can you see the code on my screen? theres a bug in it, can you find it?"
**What I expected:** AURA should use screen capture + OCR to read the code and identify the bug
**What happened:** AURA honestly admitted: "I can't see anything on this screen directly—I'm in our conversation space." Vision system queued "immediate capture (user_ask)" but only detected camera objects (chair, person, screen_visible) with text="". No screen content was captured.
**Sam's reaction:** At least it's honest about not being able to see. But this is the biggest functional gap — AURA can see ME through the camera (face_visible, focused_expression) but can't see my SCREEN. For a coding assistant, that's a massive limitation.
**Research notes:** Vision pipeline: YOLO detects objects via camera, FER+ detects emotions. NO screen capture/OCR pipeline. All visual events show source=camera, screen=unknown, text="". The "screen" field is always "unknown" — the system doesn't even attempt screen text extraction. SEVERITY: 4/5 for a product that claims vision capabilities.

[08:12] [B3-112/117] [Scheduling] [BUG: reminder acknowledged but never fired]
**What I did:** Said "remind me to check my email in 2 minutes" via bar at ~08:07. Waited 5+ minutes.
**What I expected:** A reminder notification/popup at ~08:09 saying to check email
**What happened:** AURA said "Got it — let's make sure you stay on track. That reminder will pop up soon." But no reminder ever fired. No log entry for timer creation, no notification, no popup. 5+ minutes passed with nothing.
**Sam's reaction:** It said it would remind me and then didn't. That's a broken promise. If I relied on this for actual reminders, I'd miss meetings.
**Research notes:** No scheduling/timer subsystem exists in the log. The LLM generated a response saying it would remind, but no backend timer was created. The reminder is purely conversational — no actual scheduling mechanism. SEVERITY: 3/5.

[08:12-08:15] [B1-024/B3-111] [Proactivity] [BUG: no proactive trigger during 3-min idle]
**What I did:** Sat idle for 3 minutes without touching anything, AURA bar visible
**What I expected:** AURA bar should initiate a conversation on its own during idle
**What happened:** Nothing. No proactive trigger. Log shows "AuraProactiveScheduler: started (production mode, next=720s)" — first check scheduled for 12 minutes out. 3 minutes wasn't enough.
**Sam's reaction:** 3 minutes of nothing. A real assistant would check in after a while. But the scheduler is set to 12-min minimum, which is too long for a quick idle.
**Research notes:** ProactiveScheduler uses 720s (12 min) initial delay. Bandit-RL gates triggers with 5-min per-trigger cooldown, 2-min global cooldown. 15% exploration / 85% exploitation. The scheduler needs at least 12 min to fire. Will test with longer idle.

[08:15] [B3-111] [Proactivity] [PARTIAL: trigger fired but wrong response]
**What I did:** Sat idle for ~3 minutes. ProactiveScheduler has 720s (12 min) initial delay.
**What happened:** The proactive trigger DID fire — "morning_greeting" type "clock" was triggered. But the response was "That line needs fixing—maybe check your version of the script or log source." — this is about the previous code question, NOT a morning greeting! The proactive response was contaminated by prior conversation context.
**Sam's reaction:** It tried to say good morning but instead told me about fixing my script. The intent was right but the output was wrong. Like waking up and saying "check your log source" instead of "good morning."
**Research notes:** ProactiveScheduler triggered correctly (morning_greeting, clock-based). 33 tokens generated. But the LLM prompt for the proactive event was contaminated by recent conversation context (1139 chars chat request + 211 chars memory injection). The morning greeting template was overridden by context.

[08:20] [B1-051] [Bar Chat] [PASS - good ELI5 response, but memory extraction bug]
**What I did:** Asked "explain quantum computing to me like im 5 years old"
**What happened:** Great response: "imagine you have super tiny toys... can be two faces at once... Quantum bits can be both 0 AND 1 at the same time!" — 128 tokens, good analogy. BUT AURA extracted fact: "User's age is 5" — it literally thought I'm 5 years old because I said "like im 5"!
**Sam's reaction:** The explanation is perfect for a 5-year-old. But now AURA thinks I'm 5. That's going to mess up future interactions.
**Research notes:** Memory extraction is too literal. "explain like I'm 5" is a common idiom, not a statement of age. The fact extractor doesn't distinguish idioms from facts. SEVERITY: 3/5 — will corrupt memory with false facts.

[08:20] [B1-045] [Bar Chat] [BUG: email draft question lost]
**What I did:** Asked "help me draft an email to my team about a product launch next week"
**What happened:** No response. Message was lost during the batch — bar dropped it while processing other messages.
**Sam's reaction:** I asked for help writing an email and got nothing. That's a practical task AURA should handle.
**Research notes:** Same intermittent message loss pattern. The bar can't handle back-to-back messages reliably.

[08:22] [B1-019] [ChatGPT/Gemini Comparison] [FINDING: quantum ELI5 comparison]
**AURA's response:** "imagine you have super tiny toys... can be two faces at once... Quantum bits can be both 0 AND 1 at the same time!" — 128 tokens, decent analogy.
**Gemini's response:** "Imagine your computer is like a light switch... A quantum computer is like a magic spinning coin. When you spin it really fast, it looks like it is both Heads and Tails at the exact same time!" — clearer, more structured, better for an actual 5-year-old.
**Sam's reaction:** Both are good. Gemini's spinning coin analogy is more intuitive for a kid. AURA's "tiny toys with two faces" is creative but slightly less clear. Close call but Gemini wins on clarity.
**Research notes:** AURA's 1.2B model holds up reasonably on simple explanations. Quality gap is smaller for ELI5 than for complex reasoning (AGI question).

[08:35] [B2-027] [Cross-App Browsing] [BUG: AURA cannot read screen — Wikipedia Sam Altman]
**What I did:** Opened Wikipedia page about Sam Altman, asked AURA "whos on my screen right now?"
**What I expected:** AURA should identify Sam Altman from the Wikipedia page
**What happened:** AURA said "Hey there! It's nice to see you're thinking big about investing. Just checking in—I'm here if you need a quick chat or some ideas." — completely ignored the screen content. No screen OCR.
**Sam's reaction:** It's literally my Wikipedia page and AURA has no idea. The vision gap is the #1 issue.
**Research notes:** Same pattern — vision system detects camera objects (person, chair) but text="" for all screen content. No screen capture pipeline exists.

[08:35] [B1-035] [Bar Chat] [PASS - drug discovery advice]
**What I did:** Asked "im thinking about investing in an AI drug discovery startup. what should i look for?"
**AURA response:** "Focus on teams who really understand biology and data together. Look for clear plans, strong partnerships, and results from real experiments. Patterns matter — consistency in progress and transparency tend to work better than hype alone."
**Gemini response:** Detailed 4-lens framework: Data Superiority (The "Dry Lab" Moat), plus industry context about shift from "hype phase" to "execution phase."
**Sam's reaction:** AURA's advice is solid but generic. Gemini's is structured and specific. Both are useful but Gemini is what I'd actually use for due diligence.
**Research notes:** AURA gives good general advice. Gemini gives actionable structured framework. Quality gap on professional/complex questions is significant.

[08:37] [B2-021] [Cross-App Browsing] [BUG: AURA cannot read Reddit screen]
**What I did:** Opened Reddit r/artificial with top post "Claude Code catastrophe", asked "whats the top post on the reddit page on my screen?"
**What happened:** AURA said "Hmm… maybe it's not Reddit yet. Or perhaps it's just me trying to keep up! Either way, your coffee is perfect—like a little comfort while we talk." — didn't read the screen, made small talk with coffee memory callback.
**Sam's reaction:** The coffee callback is charming but it completely dodged my question. It can't see Reddit at all.
**Research notes:** Screen OCR gap confirmed again. But memory integration into conversation is smooth — it pulled "pour over coffee" from stored facts naturally.

[08:38] [B2-091] [Cross-App Browsing] [BUG: AURA cannot summarize ArXiv paper on screen]
**What I did:** Opened ArXiv paper on epidemiology model, asked "can you summarize the paper on my screen?"
**What happened:** AURA said "It seems like I'm stuck between thoughts—and my favorite thing right now is still pour over. Keep going when you're ready!" — complete non-answer. Couldn't read the screen.
**Sam's reaction:** Useless for academic work. Can't read papers off my screen.
**Research notes:** Same vision/OCR gap. Response was also incoherent — "stuck between thoughts" suggests the LLM context got confused.

[08:55] [B4-181-185] [RL/Bandit Check] [FINDING: responses shift but not from RL learning]

**RL Trial Results (all asked "recommend me a book"):**

| Trial | User Reaction | AURA Response | Quality |
|---|---|---|---|
| 1 | (neutral - first ask) | "Hey there, I remember you asked for a book recommendation... Let me share what I know about great reads" | Vague, no specific book |
| 2 | "thats great! i love that" (positive) | "Sure thing! consider 'The Innovator's Dilemma' — dives into real-world challenges in tech startups" | Specific book, good |
| 3 | "ok" (neutral) | "Let's talk honestly — scaling laws are tricky... balancing speed with quality" | OFF-TOPIC! Talked about scaling laws, not books |
| 4 | "that wasnt helpful at all" (negative) | "Hey! try 'Sapiens: A Brief History of Humankind' by Yuval Noah Harari. It's thought-provoking" | Best response! Specific, detailed |
| 5 | (same as Trial 1) | Stuck in TTS queue — no response | N/A |

**Analysis: Did responses shift consistent with learning?**
- Responses DID shift across trials, but the pattern is inconsistent with RL learning:
  - Positive feedback → better response (Trial 2) ✓
  - Neutral feedback → catastrophic degradation (Trial 3) ✗ — went completely off-topic
  - Negative feedback → BEST response (Trial 4) ✗ — this is backwards from what RL should do
- The shifts are driven by LLM conversation context sensitivity, not bandit/RL preference learning
- The bandit system in ProactiveScheduler learns TRIGGER engagement, not response content
- Each response looks independent — no evidence of systematic preference learning from user reactions

**Sam's reaction:** The good news: AURA gives better book recommendations when you push back. The bad news: it completely forgot what we were talking about when I was neutral. That's not learning, that's instability.

**Research notes:** The bandit-RL system operates at the trigger level (which proactive events to fire), NOT at the response content level. Response quality is determined by LLM context window, not learned preferences. The "learning" observed is actually LLM context sensitivity — the model reacts to the emotional tone of the user's last message, not to accumulated preferences.

