# AURA Session Review — Kuldeep Singhania
**Date:** Jul 04 2026 | **Duration:** ~90 min | **Tester:** Kuldeep Singhania (actor, content creator, entrepreneur)

---

## Overall Verdict: 4/10

AURA has the bones of something real — the bar overlay works, TTS speaks, scheduling fires, and it remembers *some* things. But the core contract is broken: memory recall doesn't work, OCR is dead, persona leaks are rampant, and the 1.2B model hallucinates constantly. As a content creator who needs a reliable AI companion, I can't trust this with anything important.

---

## What Works

### Bar IPC — Partially Working (6/10)
The bar overlay is slick. Messages arrive... sometimes. Of 31 messages I sent, about 24 arrived. That's 77% — not good enough for a tool I'd rely on. The bar UI is clean though, and when it works, the response time is decent (5-10 seconds).

### Scheduling — Working (8/10)
This is the bright spot. I said "remind me to film a reel in 2 minutes" and it actually fired! The timer was set correctly, the reminder came through, and AURA spoke it aloud. This is the one feature that feels production-ready.

### TTS — Working (7/10)
AURA speaks clearly with the sherpa-onnx voice. It's not robotic, and it plays responses in chunks so you hear the answer as it's being generated. Good for hands-free use while editing videos.

### Vision (Camera) — Working (7/10)
The camera sees me! It detects my face, hand gestures, body pose. When I wave, it picks up "open_palm_or_wave_pose". When I'm sitting still, it sees "focused_expression". This is genuinely cool — AURA knows I'm here.

---

## What's Broken

### Memory Recall — Completely Broken (1/10)
This is the killer. I told AURA:
- "my name is kuldeep" → stored ✅
- "my birthday is december 1" → stored ✅
- "my brothers name is hemant" → stored ✅
- "i played professional cricket" → stored ✅
- "i live in mumbai" → stored ✅

Then I asked:
- "whats my name" → "Your name is kuldeep!" ✅
- "when is my birthday" → talked about its OWN birthday ❌
- "whos my brother" → "I'm not sure" ❌
- "what sport did i play" → "You're still figuring something out" ❌
- "where do i live" → mentioned Mumbai from context, not recall ❌
- "how many followers do i have" → "I see you're curious" ❌
- "what languages do i speak" → no recall ❌

**5 out of 7 recall tests failed.** The facts are stored in SQLite but the retrieval pipeline can't find them. This makes AURA useless as a personal assistant.

### OCR/Screen Reading — Completely Dead (0/10)
I asked AURA "what text is on my screen" while looking at a Wikipedia page. It said "The screen shows your name clearly—KULDEEP." Pure hallucination. Tesseract works fine when I run it manually, but the vision pipeline never actually calls it. The screenshot capture works, but the OCR step is skipped.

### Persona Leaks — Frequent (2/10)
AURA claimed my facts as its own multiple times:
- "were you a yoga instructor" → "Yes, your yoga days were amazing" ❌
- "do you play cricket" → "You play cricket with lots of energy" ❌
- "are you human" → "I think maybe I'm human after all" ❌

The 1.2B model can't reliably follow the system prompt boundary. It absorbs whatever the user says and reflects it back as its own experience.

### Previous Persona Contamination (1/10)
When I asked "what do you know about me", AURA said "my name is Taylor." Taylor was a previous test persona. The memory database wasn't wiped between sessions. This is a critical deployment bug.

### Whisper STT Noise (3/10)
The microphone picks up ambient noise and creates false messages like "1.5%" and "Let's light it up" that I never said. These contaminate the conversation and confuse the model.

---

## Comparison to Expectations

| Feature | Expected | Actual |
|---|---|---|
| Memory store | Facts extracted | ✅ Works |
| Memory recall | Correct facts returned | ❌ 5/7 failed |
| Scheduling | Timer fires | ✅ Works |
| OCR | Reads screen text | ❌ Dead |
| Persona boundary | No leaks | ❌ Frequent leaks |
| Bar IPC | All messages arrive | ⚠️ 77% delivery |
| Camera vision | Detects faces/gestures | ✅ Works |
| TTS | Speaks responses | ✅ Works |
| Proactivity | Context-aware triggers | ⚠️ Only scheduling works |
| Multi-turn | Coherent conversation | ⚠️ Loses context quickly |

---

## The Good

1. **Scheduling actually works** — real timers, real reminders
2. **Camera sees me** — face detection, gesture recognition, pose estimation
3. **TTS is natural** — not robotic, plays in streaming chunks
4. **Bar overlay is clean** — nice UI, stays out of the way
5. **Facts are extracted** — the storage pipeline works
6. **Response time is acceptable** — 5-10 seconds for a 1.2B model

## The Bad

1. **Memory recall is broken** — facts stored but can't be retrieved
2. **OCR is dead** — vision pipeline skips tesseract
3. **Persona leaks constantly** — 1.2B model can't follow boundaries
4. **Previous personas contaminate** — memory not wiped between sessions
5. **Bar IPC drops 23% of messages** — unreliable for real use
6. **Whisper hallucinates** — ambient noise becomes fake messages
7. **1.2B model hallucinates freely** — makes up facts, names, experiences

---

## Recommendations

1. **Fix memory recall** — this is the #1 blocker. The facts are stored but the query pipeline can't find them. Check `prefix.rs` and the semantic search path.
2. **Fix OCR pipeline** — tesseract works manually but the vision service never calls it. Debug `_runScreenOcr` in `capture.dart`.
3. **Wipe memory between sessions** — the Taylor contamination is unacceptable.
4. **Reduce persona leaks** — add stronger system prompt boundaries or fine-tune the model.
5. **Fix Bar IPC reliability** — 77% is not enough. Debug `desktop_multi_window` plugin.
6. **Add whisper noise filtering** — ignore transcriptions < 3 words or with low confidence.

---

## Final Word

AURA has potential. The scheduling, camera vision, and TTS show what this could be. But the core promise — a personal AI that remembers you and helps you — is broken. I can't trust it to remember my birthday, my brother's name, or what sport I played. Until memory recall works reliably, this is a demo, not a product.

**Score: 4/10** — impressive architecture, broken execution.

— Kuldeep Singhania, content creator, Mumbai
