# AURA Feature Status

Last updated: July 10, 2026

---

## WORKING (Verified in Production)

### Core Chat Pipeline
- [x] LLM inference with LFM2.5-1.2B (GGUF Q4_K_M)
- [x] Streaming token generation to Flutter UI
- [x] Multi-loop continuation for long responses
- [x] System prompt injection (ARIA persona)
- [x] Chat template support (chatml)
- [x] Cancel/interrupt generation mid-stream

### Memory System
- [x] SQLite database with 8 tables (turns, facts, vec_memory, summaries, insights, triggers, notes, proactive_log)
- [x] Fact extraction from user messages (8 categories: identity, family, pets, preferences, location, goals, emotions, events)
- [x] Prefix injection ([MEMORY: ...] prepended to prompts)
- [x] 3-tier memory retrieval (structured facts → recent turns → semantic RAG)
- [x] Hybrid search (cosine similarity + BM25 + recency boost)
- [x] Consecutive-memory guard (prevents repetition)
- [x] Durable JSONL mirror (survives app reinstall)
- [x] Question detection (prevents storing questions as facts)
- [x] Fact validation (valid_profile_fact() — 80+ allowed prefixes)
- [x] Correction detection ("actually", "just kidding" triggers fact deletion)

### ARIA Persona
- [x] Teenage girl personality (warm, witty, curious)
- [x] Never says "As an AI" or "I am a language model"
- [x] 1-3 sentence response style
- [x] 15 persona case files (greetings, identity, emotions, memory recall, etc.)
- [x] Compile-time embedded persona bank

### AURA Bar (Companion UI)
- [x] Persistent floating companion pill
- [x] Waveform visualization
- [x] Particle effects
- [x] State-driven UI (idle, thinking, speaking, proactive)
- [x] Tray icon integration
- [x] Independent window lifecycle (Linux)
- [x] Proactive message bubbles

### Voice (STT/TTS)
- [x] STT: Sherpa-onnx Zipformer (20M int8)
- [x] TTS: Sherpa-onnx Piper (en_US-lessac-medium)
- [x] Online TTS fallback (Google Translate TTS)
- [x] Voice activity detection (VAD)
- [x] Streaming TTS (speaks sentences during generation)

### Vision (Basic)
- [x] Webcam capture (V4L2 on Linux, CameraX on Android)
- [x] YOLOv8n object detection
- [x] YOLOv8n-pose estimation
- [x] Emotion detection (FER+ 8-class)
- [x] Vision gate (confidence + cooldown)
- [x] Visual event storage

### Performance
- [x] Performance tier detection (Strong/Balanced/Constrained)
- [x] Platform-specific thread/context config
- [x] KV cache warmup (system prompt prefill)
- [x] TTFT optimization (34-55ms)
- [x] Deferred fact extraction (after generation starts)

### Multi-Window (Linux)
- [x] Independent lifecycles (AURA Bar + Main Dashboard)
- [x] Hide strategy (closing Main hides it, keeps engine alive)
- [x] Cross-window communication
- [x] Full exit only when last window closes

---

## WORK IN PROGRESS (Partially Implemented)

### Memory System Enhancements
- [ ] Multi-fact pre-fill variant ("Here's what I know about you: ")
- [ ] Char-budget cap on facts injection (2000-char ceiling)
- [ ] BM25 tuning (K1, B, bm25_scaled multiplier)

### Vision Enhancements
- [ ] MediaPipe ObjectDetector (TFLite, ~2MB) for better detections
- [ ] Real hand/pose landmark model for gesture detection
- [ ] Real face/expression model for emotion detection
- [ ] CLIP image embeddings for visual RAG
- [ ] Visual context injection (max 3 vision lines per query)

### Voice Enhancements
- [ ] Android STT reliability (permission, speech recognizer)
- [ ] Android TTS smoothness (platform TTS slow/choppy)
- [ ] Visible diagnostics for translation/TTS source

### Android
- [ ] Android proactive overlay routing (update/speak in overlay)
- [ ] Overlay click blocker fix (compact state)
- [ ] Keyboard focus block fix (FLAG_NOT_FOCUSABLE)

### Proactive System
- [ ] Model-written English nudges (no canned phrases)
- [ ] Context-aware timing (screen, camera, speech, text)
- [ ] Gesture/vision response routing

---

## FUTURE SCOPE (Not Yet Started)

### Memory System
- [ ] Long-term memory consolidation (summarize old turns)
- [ ] Memory decay (forget irrelevant facts over time)
- [ ] Cross-device memory sync
- [ ] Memory export/import
- [ ] User-facing memory editor

### Vision
- [ ] Scene understanding (beyond object detection)
- [ ] Image captioning
- [ ] Video memory (record and recall visual events)
- [ ] AR overlay (visual annotations)

### Voice
- [ ] Multi-language support (beyond English)
- [ ] Voice cloning (custom ARIA voice)
- [ ] Emotion-aware TTS (adjust tone based on context)
- [ ] Whisper local (replace Python server)

### Persona
- [ ] Multiple persona support (user-selectable)
- [ ] Persona evolution (learn from user interaction)
- [ ] Custom persona creation tool
- [ ] Persona marketplace

### Integration
- [ ] Calendar integration (proactive reminders)
- [ ] Email/message summarization
- [ ] Smart home control
- [ ] Web search integration
- [ ] File system navigation

### Platform
- [ ] iOS support
- [ ] Windows support (partial)
- [ ] Web support (WASM)
- [ ] Browser extension

### Training
- [ ] Fine-tuning pipeline (SFT/DPO)
- [ ] User feedback loop (RLHF)
- [ ] Dataset generation from conversations
- [ ] Model distillation (1.2B → 450M)

---

## KNOWN ISSUES

### Critical
- **450M Aria model identity confusion** — Says "I'm Luna" instead of "I'm ARIA" (confuses user with persona)
- **Cat name recall failure** — Both models fail to recall "Mochi" when asked "what's my cat's name?"
- **Ramen recall failure** — Both models fail to recall "ramen" when asked "what do I love?"

### Minor
- **Memory dumps** — Sometimes injects memory list instead of answering naturally
- **Poem cut-off** — Short poems get truncated mid-sentence
- **Vague AI answers** — "I don't know. but I can imagine." for speculative questions
- **Tokyo stored as current** — "I used to live in Tokyo" stored as current location, not past

### Performance
- **Slow inference on CPU** — 1.2B: ~18.8s per response, 450M: ~5.5s per response
- **High RAM usage** — ~8GB for 1.2B model on CPU

---

## MODEL COMPARISON SUMMARY

| Metric | LFM2.5-1.2B | LFM2.5-VL-450M (Aria) |
|--------|-------------|------------------------|
| Persona | 5/10 | 1/10 |
| Recall | 7/10 | 7/10 |
| Quality | 5/10 | 5/10 |
| **Total** | **17/30** | **13/30** |
| tok/s | ~0.7 | ~3.2 |
| Cold warmup | 17.0s | 5.5s |
| RAM | 7.97 GB | 7.98 GB |

**Decision: Ship 1.2B** — Better persona adherence, no identity confusion bugs.

---

## RECOMMENDED NEXT STEPS

1. **Fix cat name recall** — Both models fail on "what's my cat's name?" despite having "User has a cat named Mochi" in the facts table. Investigate prefix injection or retrieval issue.

2. **Fix ramen recall** — Same issue. "what do I love?" should recall "User loves ramen".

3. **Improve persona adherence** — Current 5/10 score. Focus on reducing memory dumps and improving natural responses.

4. **Add multi-fact pre-fill** — For broad queries like "what do you know about me?", use "Here's what I know about you: " prefix.

5. **Tune BM25 parameters** — May help with recall for specific queries.

6. **Test on Android** — Verify STT/TTS and overlay work on mobile.
