# AURA Decision Log — Local LLM Switch Rationale & Timeline

**Date:** June 28, 2026  
**Document:** Decision Log & Architecture Switch  
**Context:** Evaluation of local LLM (`LFM2.5-230M-Q8_0.gguf` via `llama-cpp-2` in Rust) versus cloud-based models (Gemini API).

---

## 1. Architectural Choice: Local LLM Switch Rationale

During Phase 3 and Phase 4, the team reviewed the integration of cloud-based APIs (Gemini API) and ultimately decided to switch back to a fully local model (LFM-230M). The core reasons for prioritizing the local model are outlined below:

### A. Privacy and Data Sovereignty
AURA's memory subsystem continuously records user self-disclosures, personal preferences, relationship context, and camera/vision events. Sending this highly sensitive, private personal data to external cloud APIs poses severe privacy risks and violates the user's data sovereignty. A fully offline Rust model ensures that no personal conversation context ever leaves the user's device.

### B. Latency Independence and Cost
- **Local Inference:** Running LFM-230M Q8_0 on CPU yields stable speed (~75–93 tokens/s) with a low and predictable TTFT (~240–450ms) completely independent of network state.
- **Cloud API:** Subject to network roundtrips, request queues, throttling, and API rate limits. Additionally, cloud inference introduces billing costs scale-linked to user interaction frequency.

### C. Offline Reliability
As an always-on assistant, AURA must remain functional in offline settings (e.g., planes, subways, or areas with poor coverage). Relying on a cloud API bricked the chat capability during offline periods, whereas the local Rust worker remains fully operational.

### D. Hybrid Voice Strategy (Online TTS/STT with Local Fallback)
While LLM reasoning is kept fully local for privacy and availability, the speech interfaces utilize a hybrid approach:
- **Online Edge TTS (`en-US-AvaNeural`)** is preferred for natural, emotionally expressive speech to prevent robotic vocal fatigue. A local, offline `sherpa-onnx` VITS model serves as a zero-network fallback.
- **Whisper STT** runs on a local GPU server (when available) or utilizes local audio transcription to ensure accurate speech recognition.

---

## 2. Structured Timeline of Commits & Milestones

The following log tracks all significant timeline updates and modifications appended to the AURA repository:

### Milestone 1: Memory Foundation (May 31, 2026)
- **What:** Setup of SQLite WAL connection pool, `turns`, `summaries`, `facts`, and `vec_memory` schemas.
- **Results:** HashMap-based Layer 1 cache created, delivering O(1) lookup speed (~0.25 µs) for names/greetings. Passed Phase 2 Gate early: AURA successfully remembered user name across sessions.

### Milestone 2: Micro-benchmarks & Proactive Triggers (June 7, 2026)
- **What:** Implementation of `latency.rs`, `ablation.rs`, and micro-benchmarks for PCM sliding windows and BinaryHeap priority queues.
- **Results:** Verified that release build Ring Buffers operate at ~1 ns/op, proving zero real-time audio thread latency overhead.

### Milestone 3: Memory Recall Accuracy Evaluation (June 25, 2026)
- **What:** Evaluated LFM-230M and BGE-small embedding RAG against 500 generated test cases in `memory_test.rs`.
- **Results:** Achieved **71.00% overall recall accuracy** (95.00% on simple preference recall). Identified verbosity and formatting truncation under small token budgets as core areas for improvement.

### Milestone 4: Switchback, Looping & Vision Gestures (June 28, 2026)
- **What:** Finalized transition back to local model, stripped rigid guardrails, optimized Edge TTS robust module invocation, and implemented webcam gesture detection.
- **Key Enhancements:**
  1. **Brief Looping & Streaming:** Enabled token-by-token streaming and continuation looping (`plan.continuation`) in AURA Bar brief mode, raising the token cap from 160 to 384.
  2. **Robust Edge TTS Fallback:** Configured `try_edge_tts` in Rust to search for `python3 -m edge_tts` and local PATHs first, preventing premature fallback to local VITS.
  3. **Lightweight Motion/Gesture Detection:** Integrated frame differencing (motion tracking via pixel sampling) in `webcam.rs` running at 30 FPS. Sets `GESTURE_PENDING` and injects `"user waving / hand gesture"` into the YOLOv8 detections list, feeding AURA's visual context.
