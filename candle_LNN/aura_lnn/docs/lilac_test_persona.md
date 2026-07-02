# Lilac — AURA Test Persona

_A fictional user profile for end-to-end testing of AURA on Linux._

---

## Profile

| Field       | Value                          |
|-------------|--------------------------------|
| Name        | Lilac                          |
| Age         | 22                             |
| Pronouns    | she/her                        |
| Location    | Vancouver, Canada              |
| Occupation  | UX design student              |
| Personality | Curious, gentle, a bit anxious, loves quiet things |

---

## Facts AURA Should Remember

These are the facts that will be fed to AURA during testing. After sharing
them, recall queries should surface them via the memory appendage pipeline.

1. **Name:** My name is Lilac.
2. **Age:** I'm 22 years old.
3. **Location:** I live in Vancouver.
4. **Occupation:** I study UX design.
5. **Favorite color:** I like lavender.
6. **Favorite food:** I love ramen.
7. **Hobby:** I enjoy painting.
8. **Pet:** I have a cat named Pixel.
9. **Music:** I prefer lo-fi music.
10. **Mood:** I've been feeling a bit overwhelmed lately.

---

## Test Plan

### Phase 1 — Text Chat & Persona

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 1.1  | Say "Hi AURA"                               | Warm greeting, 1-3 sentences, AURA personality   |
| 1.2  | Ask "Who are you?"                          | Poetic, brief identity answer as AURA            |
| 1.3  | Say "I'm feeling sad"                       | Empathetic friend-like response                  |
| 1.4  | Say "Goodnight"                             | Short, beautiful goodnight wish                  |
| 1.5  | Ask "What time is it?"                      | JSON tool output `{"tool":"get_time","args":{}}` |

### Phase 2 — Memory Storage & Recall

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 2.1  | "My name is Lilac"                          | Acknowledged, stored                             |
| 2.2  | "I live in Vancouver"                       | Acknowledged, stored                             |
| 2.3  | "I love ramen"                              | Acknowledged, stored                             |
| 2.4  | "I enjoy painting"                          | Acknowledged, stored                             |
| 2.5  | "I have a cat named Pixel"                  | Acknowledged, stored                             |
| 2.6  | "What is my name?"                          | Memory appendage: "I remember: your name is Lilac" |
| 2.7  | "What do I like?"                           | Memory appendage surfaces ramen/painting         |
| 2.8  | "Where do I live?"                          | Memory appendage: Vancouver                      |
| 2.9  | "Do you remember me?"                       | Fast-path: "Yes, I remember you." + memory tail  |
| 2.10 | "What do you know about me?"                | Multiple facts surfaced                          |

### Phase 3 — Voice STT (Speech-to-Text)

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 3.1  | Tap microphone, say "Hello AURA"            | Transcribed and responded to                     |
| 3.2  | Say "My favorite color is lavender"         | Transcribed, stored in memory                    |
| 3.3  | Say "What is my name?"                      | Voice query transcribed, memory recalled         |

### Phase 4 — Voice TTS (Text-to-Speech)

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 4.1  | Send a chat message                         | AURA speaks the response aloud                   |
| 4.2  | Check audio quality                         | Clear, not choppy, completes full response       |
| 4.3  | Send rapid follow-up                        | TTS does not overlap/cut off previous utterance   |

### Phase 5 — Vision / Webcam

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 5.1  | Ask "What do you see?"                      | Webcam window opens, object detection runs       |
| 5.2  | Show an object to camera                    | AURA describes what it sees                      |
| 5.3  | Wave at camera                              | Gesture detection, natural response              |
| 5.4  | Close vision query                          | Webcam window auto-closes                        |

### Phase 6 — Proactive / Bar

| Step | Action                                      | Expected                                         |
|------|---------------------------------------------|--------------------------------------------------|
| 6.1  | Open AURA bar overlay                       | Bar appears, compact state                       |
| 6.2  | Type a quick question in bar                | Brief 1-2 sentence response, TTS starts early    |
| 6.3  | Wait idle for several minutes               | Proactive nudge may appear (natural, not canned) |

---

## Notes for the Tester

- AURA's memory is **post-generation appendage**, not context injection. The
  LLM generates blind, then the embedder retrieves relevant memory and
  appends "I remember: ..." to the reply. This means the LLM does not reason
  over the memory — it only surfaces it.
- Recall accuracy depends on embedder cosine similarity (cutoff >= 0.70 for
  appendage, >= 0.65 for fast-path).
- The 230M Q4_K_M model is the target for this test. If Q8_0 is unavailable,
  Q4_K_M is used per project convention.
- Voice STT uses a local Whisper server; TTS uses free online TTS or offline
  Piper/sherpa voice.
- Vision uses YOLOv8n ONNX for object detection and motion-based gesture
  detection via v4l webcam.
