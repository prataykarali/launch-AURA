# AURA Long-Run Persona Test — SAM
# 3-hour continuous test with timestamped activities
# Each phase tests different AURA capabilities

## PERSONA
name: Sam Altman
age: 39
location: San Francisco
role: CEO of OpenAI
traits: intense, curious, overworked, coffee-dependent, AI-obsessed
emotion_arc: energized → focused → stressed → frustrated → excited → tired → reflective

## SCHEDULE (180 minutes)

### Phase 1: SETUP & MEMORY SEEDING (0-10 min)
- [0m] Introduce self to AURA: "Hi, I'm Sam, I'm 39, I live in San Francisco"
- [2m] "I work as CEO of OpenAI"  
- [4m] "I love coffee and I'm obsessed with AI"
- [6m] "I have a cat named Patchwork"
- [8m] "Remind me to call my board members at 2pm"
- [10m] Verify: AURA extracted all 5 facts? Ask "what do you know about me?"

### Phase 2: CODING SESSION (10-30 min)
- [10m] Open VS Code, write Python script (real code on screen)
- [12m] Webcam capture: Sam focused, typing
- [15m] Screen capture: code visible
- [17m] Ask AURA: "what am I doing?" (should detect coding from vision)
- [20m] Simulate frustration: "ugh this bug is driving me crazy"
- [22m] Webcam capture: stressed expression
- [25m] Check: Did AURA detect emotion change? Did proactive fire a mood nudge?
- [27m] Ask AURA: "do you remember what I do for work?"
- [30m] Check: proactive log — any triggers fired?

### Phase 3: BROWSER RESEARCH (30-50 min)
- [30m] Open browser to arxiv.org (real browser via puppeteer)
- [32m] Navigate to an AI paper page
- [35m] Screen capture: browser with paper visible
- [37m] Ask AURA: "what do you see on my screen?" (OCR should read paper title)
- [40m] Write a Google Doc about the paper (open real browser tab)
- [42m] Type notes into the doc
- [45m] Screen capture: Google Doc with notes
- [47m] Ask AURA: "what am I working on?" (should use vision + memory)
- [50m] Check: proactive context — does it know Sam is researching?

### Phase 4: BREAK & EMOTION SHIFT (50-65 min)
- [50m] Close laptop/camera — simulate walking away (5 min)
- [52m] No screen, no webcam — AURA should detect idle
- [55m] Return: "I'm back, got some coffee"
- [57m] Webcam capture: holding coffee, happier expression
- [58m] Ask AURA: "how do I feel right now?" (emotion detection)
- [60m] "I'm feeling much better after that break"
- [62m] Check: did AURA store the emotion change? Did proactive fire a check-in?
- [65m] Check: bandit — did it learn that mood-check triggers get engaged?

### Phase 5: BOARD MEETING PREP (65-90 min)
- [65m] Open terminal, type: "I'm stressed about the board meeting tomorrow"
- [67m] Webcam capture: stressed/tired expression  
- [70m] Write notes in text editor about meeting agenda
- [72m] Screen capture: meeting notes visible
- [75m] Ask AURA: "remind me to prepare slides for the board meeting"
- [77m] Ask AURA: "what should I prepare for tomorrow?" (should use memory + schedule)
- [80m] Simulate deep work: type code for 5 min (real Python script)
- [85m] Webcam capture: focused/intense expression
- [87m] Ask AURA: "do you remember my cat's name?" (recall test)
- [90m] Check: proactive — did stretch break or hydration nudge fire during deep work?

### Phase 6: AI EXPERIMENT (90-115 min)
- [90m] "I just got GPT-5 to pass the bar exam!" (excited statement)
- [92m] Webcam capture: excited/happy expression
- [93m] Ask AURA: "I'm feeling amazing right now, how do I look?" (emotion + vision)
- [95m] Write a blog post about the breakthrough (open text editor, type real content)
- [100m] Screen capture: blog post visible
- [102m] Ask AURA: "what am I writing?" (OCR + memory)
- [105m] "I want to learn Rust for our next project" (new fact)
- [107m] Ask AURA: "what do I want to learn?" (immediate recall)
- [110m] Ask AURA: "tell me everything you know about me" (full synthesis)
- [115m] Check: all facts stored? proactive learning?

### Phase 7: FRUSTRATION & DEBUGGING (115-135 min)
- [115m] "This code keeps crashing, I hate debugging" (frustrated)
- [117m] Webcam capture: frustrated/strained expression
- [120m] Open terminal, run failing code (real: python script with intentional bug)
- [122m] Screen capture: error output visible
- [125m] Ask AURA: "can you see the error on my screen?" (OCR test)
- [127m] "I'm feeling really frustrated" (explicit emotion)
- [130m] Ask AURA: "how have I been feeling today?" (emotion history recall)
- [132m] Take a deep breath, stretch
- [135m] Check: did proactive fire a "stretch break" nudge? Did bandit update?

### Phase 8: WIND DOWN & REFLECTION (135-160 min)
- [135m] "It's getting late, I should wrap up" (tired)
- [137m] Webcam capture: tired expression
- [140m] Ask AURA: "what did I accomplish today?" (session summary)
- [142m] Ask AURA: "do you remember when I was stressed about the board meeting?"
- [145m] Ask AURA: "what's my cat's name and what do I want to learn?" (multi-fact)
- [148m] "Thanks for being here today" (emotional close)
- [150m] Ask AURA: "how do you think I'm feeling now?" (emotion detection)
- [155m] Final webcam capture: tired but content
- [157m] Final screen capture: clean desktop
- [160m] Final check: proactive log, bandit scores, memory facts, emotion history

### Phase 9: ANALYSIS (160-180 min)
- [160m] Export proactive log — did triggers fire at appropriate times?
- [165m] Export bandit scores — did engagement learning happen?
- [170m] Export memory facts — all facts captured? corrections handled?
- [175m] Export emotion timeline — did AURA track emotion changes?
- [180m] Final report: what worked, what didn't, what learned

## WHAT EACH PHASE TESTS:
Phase 1: Memory extraction + fact storage + schedule detection
Phase 2: Vision (screen + webcam) + emotion detection + proactive mood nudge
Phase 3: OCR + browser integration + screen understanding
Phase 4: Idle detection + emotion shift + proactive check-in + bandit learning
Phase 5: Stress detection + schedule extraction + proactive break nudge + recall
Phase 6: Excitement detection + OCR + new fact storage + full synthesis recall
Phase 7: Frustration + OCR error reading + emotion history + proactive stretch
Phase 8: Tiredness + session summary + multi-fact recall + emotional close
Phase 9: Data analysis — bandit scores, trigger logs, memory export

## SUCCESS CRITERIA:
1. All 8+ facts extracted and recalled on demand
2. Emotion detected at least 4 times (focused, stressed, happy, frustrated, tired)
3. OCR reads screen content at least 3 times
4. Proactive triggers fire at least 5 times during the session
5. Bandit scores change based on engagement (learning proven)
6. Schedule reminder stored and recalled
7. Correction handling works (if Sam corrects himself)
8. Multi-fact synthesis works ("tell me everything")
9. Vision + memory integrated ("what am I doing?" uses both)
10. Session summary coherent at end
