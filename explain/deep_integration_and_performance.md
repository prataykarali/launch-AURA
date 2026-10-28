# AURA Architecture Deep-Dive: Integration, Performance, Voice & Memory

This document provides a highly detailed walkthrough of Project AURA’s integration FFI layer, model performance metrics, STT/TTS voice system mechanics, and memory layer optimizations.

---

## 1. Flutter-to-Inference Connection & Thread Orchestration

AURA relies on the **Flutter-Rust Bridge (FRB)** FFI layer to connect the Dart UI process with the localized Rust inference core (`candle_LNN`).

### A. Threading Boundaries & IPC Flow
To keep the UI smooth at 60+ FPS, all heavy inference and file operations are completely decoupled from the Dart main thread.

```
┌────────────────────────────────────────────────────────────────────────┐
│ Dart UI Thread (Flutter)                                               │
│  - Triggers auraChat(prompt) or mic taps                                │
│  - Receives streamed text tokens asynchronously from StreamSink        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Non-blocking FFI Call)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Rust FFI Boundary (api/mod.rs)                                         │
│  - Receives String prompts and StreamSink<String> callbacks            │
│  - Pushes EngineMsg variant to the SyncChannel (bounded capacity 20)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (EngineMsg SyncChannel)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Rust Dedicated Worker Thread ("aura-engine-worker")                    │
│  - Holds the Mutex for LlamaEngine, MemoryStore, and STT engine        │
│  - Processes one EngineMsg at a time (guarantees transaction safety)   │
│  - Streams tokens back via StreamSink.add()                            │
│  - Dispatches turns to the background embed worker                     │
└────────────────────────────────────────────────────────────────────────┘
```

### B. FFI Streams and Recurrent State Synchronization
*   **Asynchronous Token Streaming**: As the model generates tokens, the worker calls the FFI callback `on_token`. This uses FRB's `StreamSink<String>` to push tokens directly into Dart’s event stream, bypassing poll-waiting.
*   **Recurrent Gated Delta Net constraints**: Because the recurrent state cannot be partially rewound:
    *   **No speculative pre-filling**: Previous speculative logic was writing tokens at arbitrary indices in the KV-cache without updating `n_past`, triggering "inconsistent sequence position" faults. The FFI layer disables speculative pre-filling.
    *   **Context Reset**: The FFI boundary detects when `n_past` climbs past the watermark ($3/4$ context window size) and performs a clean FFI reset `aura_reset_state()` between user turns.

---

## 2. Performance Verification Metrics

Verification metrics were measured on a Linux development machine (Aspire A515-58GM, Ubuntu) using CPU-only inference:

*   **Warmup Performance**:
    *   Cold Start (system prompt cache prefill): **0.78s**
    *   Warm Start (cache reload): **0.80s**
*   **KV Cache I/O**:
    *   Load Latency: **0.80s**
    *   Cache Memory footprint: **17.7 MB**
*   **Inference Speeds (LFM-230M)**:
    *   Short chat turns: **84.6 tokens/sec**
    *   Medium instruction turns: **80.6 tokens/sec**
    *   Long emotional context turns: **67.4 tokens/sec**
    *   **Aggregate Throughput**: **72.3 tokens/sec**
*   **Cache Speedup**:
    *   *KV Cache Hit*: **39ms Time-to-First-Token (TTFT)**
    *   *KV Cache Miss (Full Decode)*: **1041ms TTFT**
    *   *Speedup Factor*: **26.6x**

---

## 3. STT / TTS Subsystems: Workflows, Errors, and Fixes

Voice integration differs between desktop (Linux) and mobile (Android):

```
STT Input Flow (Linux):
  [arecord raw audio] ──► [Whisper Python Server] ──► [FFI JSON result] ──► Chat Engine
STT Input Flow (Android):
  [Mic Button Tap] ──► [Native SpeechRecognizer] ──► [MethodChannel] ──► Chat Engine

TTS Output Flow (Linux):
  Chat Sentence ──► [sherpa-onnx VITS / Piper] ──► [rodio Audio Sink] ──► Speaker
TTS Output Flow (Android):
  Chat Sentence ──► [Android TextToSpeech API] ──► MethodChannel ──► Speaker
```

---

### A. STT (Speech-to-Text)

#### Linux Workflow
1.  Dart spawns `arecord` to capture microphone input to a temporary WAV file.
2.  A persistent child Python process (`whisper_server.py`) is warmed up on launch.
3.  Once recording stops, Dart sends the WAV path to the Whisper server's stdin, which runs the `whisper-base.en` model on the GPU and returns the text.

#### Android Workflow
*   Uses the platform-native Android `SpeechRecognizer` wrapped by the `speech_to_text` Flutter package via MethodChannels.

---

### B. TTS (Text-to-Speech)

#### Linux Workflow
1.  Exposes `aura_tts_init` to load a `sherpa-onnx` VITS offline voice (`piper` `.onnx` model).
2.  `aura_tts_speak` pushes speech sentences to a Rust thread queue.
3.  A background thread generates raw PCM audio and writes it directly to a `rodio` output audio stream sink.

#### Android Workflow
*   Dispatches text strings back to Dart, which calls the native Android `TextToSpeech` API via MethodChannels.

---

### C. Critical Voice Errors & Fixes to Resolve

#### 1. Background Microphone Block (Android Overlay)
*   **Root Cause**: [OverlayService.java#L251-L256](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java#L251-L256) promotes its background service to a foreground service using `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK` only. When backgrounded, Android blocks mic capture.
*   **Fix**: Update the Android Java service promotion to include the microphone flag:
    ```java
    startForeground(OverlayConstants.NOTIFICATION_ID, notification,
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK |
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
    ```

#### 2. Piper ONNX sample_rate Metadata Probe Failure (Linux TTS)
*   **Root Cause**: [tts.rs#L39-L103](file:///home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/src/api/tts.rs#L39-L103) checks the Piper ONNX graph properties for `sample_rate`. Raw exports from HuggingFace only define the rate in their `.json` sidecars, so the Rust parser fails with `metadata probe FAIL` and disables TTS.
*   **Fix**: Inject a fallback case in `tts.rs`: if ORT metadata props do not contain `sample_rate`, read it from the sibling `.json` config file or default to `16000` / `22050` Hz based on model low/medium presets.

#### 3. Unreachable Rust STT Block (Linux STT)
*   **Root Cause**: In [stt_service.dart#L92-L117](file:///home/pratay-karali/launch-AURA/aura_notebook/lib/services/stt_service.dart#L92-L117), a duplicate `Platform.isLinux` check causes the STT initialization to return early, leaving the Rust-side Zipformer engine dead code.
*   **Fix**: Change the second check from `Platform.isLinux` to `Platform.isAndroid` to isolate Rust Zipformer STT to Android and allow correct fallbacks on Linux.

#### 4. ALSA EBUSY Locks & Zombie Whisper processes (Linux STT)
*   **Root Cause**: Spawning concurrent `arecord` subprocesses locks the ALSA driver on raw-device configurations. Whisper subprocesses are never cleaned up on crash.
*   **Fix**: Update `stt_service.dart` to share a single audio capture thread, and register a Dart window exit callback (`window_manager` listener) to run `Process.killPid()` on the Python child process.

---

## 4. Memory Layer: Data Structures & Optimizations

The memory system is built around SQLite, WAL connection pooling, and dense vector indexes.

### A. Core Memory Data Structures
*   **SQLite ConnPool** (`pool.rs`): Runs SQLite in **WAL (Write-Ahead Logging)** mode with busy timeouts to allow concurrent background inserts (like passage embeddings) while the foreground thread reads chat logs.
*   **Memory Tables**:
    *   `turns` - speaker, content, timestamp.
    *   `facts` - extracted core facts.
    *   `vec_memory` - stores dense embeddings alongside passage texts.
    *   `triggers` - maps proactive items using an **epsilon-greedy reinforcement learning bandit** algorithm to select triggers based on engagement scores.
*   **Ring Buffers & Sliding Windows** (Rust `VecDeque`):
    *   An off-heap PCM Ring Buffer (capacity 8) processes raw audio samples quickly for Picovoice Voice Activity Detection (VAD).
    *   A Sliding Window (capacity 20) manages context boundaries, checking whether user turns have hit thresholds.

---

### B. Implemented Memory Optimizations

#### 1. Layer 1 Facts Cache (HashMap Cache)
*   **How it works**: Bypasses SQLite read latencies during FFI load. Key profile values (like username, preferences) are read into an in-memory `HashMap<String, String>` once on session startup.
*   **Performance Impact**: Reduces fact read lookup times from **6.8 µs** (SQL) to **0.25 µs** (HashMap) — a **28x speedup**.

#### 2. Hybrid BM25 + Cosine Retrieval
*   **How it works**: Pure vector search is prone to cosine collisions when matching short names or pronouns. A hybrid retrieval function was added to pre-filter candidate facts using a **BM25 keyword match** before computing embedding similarities.
*   **Performance Impact**: Relationship graph recall accuracy rose by **+21%** (from 50% to 71%) by forcing matches on exact names.

#### 3. Topic Drift Cosine Centroid Tracking
*   **How it works**: Monitors context topic shifts by tracking the cosine distance of the latest turn embedding from the rolling centroid of the last 8 turns.
*   **Performance Impact**: If distance drift exceeds `0.35`, the engine signals a topic-shift event to automatically fold old turns into a summary and trim the context cache, keeping prompt bounds lean.

#### 4. XML Profile Isolation & Pre-filling
*   **How it works**: Wraps facts in custom XML instructions and pre-fills assistant tokens (e.g., `Based on what I know about you, your sister...`).
*   **Performance Impact**: Stops model safety disclaimers and hallucinations, boosting emotional recall accuracy from **33% to 73% (+40%)**.
