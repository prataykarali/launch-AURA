# Vision Memory Plan

Goal: add visual sensing without bloating AURA or making chat latency worse on A16-class phones.

The vision system must behave like a low-power sensory layer. It observes, compresses, and stores useful context. The main LLM should not process raw frames and should not wait for vision on normal chat turns.

## Core Rule

Vision is asynchronous.

```text
camera/frame
  -> vision worker
  -> visual event filter
  -> visual memory store
  -> retrieval gate
  -> short context line for LLM only when needed
```

Never do this:

```text
user sends message
  -> run camera model
  -> embed frame
  -> retrieve memories
  -> then start LLM
```

That path will make TTFT feel broken.

## Module Shape

Keep vision separate from `engine` and `memory`.

```text
src/vision/
  mod.rs              public API and worker lifecycle
  capture.rs          frame input adapters from Flutter/native
  detector.rs         object/pose/scene model wrapper
  events.rs           converts detections into compact events
  gate.rs             throttling, dedupe, importance scoring
  store.rs            visual observation persistence
  summary.rs          compact text summaries for LLM context
```

Do not put vision model logic in `engine.rs`.
Do not put camera/frame code in `memory/store`.
Do not call the main LLM from `vision`.

## Runtime Budgets

Target phone: A16-class, CPU-first, battery-sensitive.

| Task | Budget |
| --- | ---: |
| LLM TTFT for normal chat | should not wait on vision |
| Vision polling interval | 500ms-2s |
| Vision model runtime | under 80ms target, under 150ms max |
| Visual event embedding | only on important events |
| Visual memory injected to LLM | 1-3 short lines |
| Stored visual event text | under 220 chars |
| In-memory visual cache | last 20-50 events |

If the phone is warm, battery is low, or the LLM is generating, slow vision to 2-5s or pause it.

## Model Choice

Start with a mobile-native vision stack.

Preferred first version:

```text
MediaPipe Object Detector or Image Embedder
```

Use YOLO only if you need custom object classes or better detection quality.

If using YOLO:

```text
YOLO11n or another nano/mobile export
ONNX/TFLite/CoreML depending on target
quantized if possible
```

Avoid YOLOv5 as the first choice unless there is already working tooling around it. It is older and not the best default for a new mobile path.

## Event Flow

The vision model should output structured detections:

```rust
struct VisionDetection {
    label: String,
    confidence: f32,
    bbox: Option<[f32; 4]>,
}
```

The event builder converts detections into compact text:

```text
"vision: laptop and notebook visible on desk"
"vision: user appears away from screen"
"vision: dim room, phone held close"
```

Only compact text goes to memory. Raw frames should not be stored by default.

## Importance Gate

Embed/store only if an event is important.

Important:

```text
new object category appears
object persists for several frames
scene changes strongly
user explicitly asks "what do you see?"
visual event relates to current conversation
emotion/posture cue changes noticeably
```

Not important:

```text
same laptop detected again
confidence below threshold
minor bbox movement
background object flicker
duplicate label within cooldown
```

Suggested gate:

```text
confidence >= 0.55
AND not duplicate within 10-30s
AND importance_score >= 0.5
```

## Timing Policy

Use adaptive polling:

```text
active visual mode:        every 500ms
normal companion mode:     every 1-2s
LLM currently generating:  pause or every 3-5s
battery saver:             pause
screen off:                pause
camera permission absent:  disabled
```

Run detection on a worker thread. Never block the engine thread.

## Memory Integration

Store visual events as ordinary memory episodes with a dedicated role:

```text
role = "vision"
content = "vision: laptop and notebook visible on desk"
```

This lets existing retrieval work without a separate database first.

Later, if visual memory grows, split it into:

```text
visual_events
visual_embeddings
visual_scene_summaries
```

Do not start with that unless the simple role-based approach becomes too noisy.

## LLM Context Policy

The LLM only sees visual context when one of these is true:

```text
user asks about surroundings
user asks "what do you see?"
conversation depends on visible state
vision event has high importance
recent visual event resolves ambiguity
```

Injected context must be short:

```text
Visual context:
- laptop and notebook visible on desk
- room appears dim
```

Hard limit: 3 lines.

## Embedding Policy

Do not embed every frame.

Embed only:

```text
deduped visual event text
scene summary every few minutes
user-triggered visual observation
```

Recommended first storage:

```rust
store.insert_episode(session_id, "vision", event_text, embedder)
```

Then retrieval can find visual memories when relevant.

## Main LLM Role

The main LLM should reason over compact sensory facts.

Good:

```text
User: what do you see?
Context: "vision: notebook and laptop visible on desk"
AURA: "looks like study mode again. laptop, notebook, the whole little battlefield."
```

Bad:

```text
send image/frame to LLM every turn
ask LLM to classify objects
ask LLM to decide every visual event
```

Use the main LLM for optional background polish only:

```text
raw visual events -> background summary -> "User studied at desk for a while"
```

This should run rarely and never block chat.

## File Boundaries

Keep files small:

```text
detector.rs      under 250 lines
events.rs        under 200 lines
gate.rs          under 200 lines
store.rs         under 200 lines
summary.rs       under 150 lines
```

If any file grows past that, split by responsibility.

## First Implementation Milestone

Milestone 1: no model yet, just prove the pipeline.

```text
1. Add VisionEvent struct
2. Add VisionGate dedupe/importance logic
3. Add store_visual_event wrapper
4. Add retrieval formatting for recent visual events
5. Add tests for dedupe and cooldown
```

Use fake detections:

```text
laptop, notebook, face, phone
```

Milestone 2: plug in real detector.

```text
1. Add detector backend trait
2. Add MediaPipe/TFLite implementation
3. Add frame throttling
4. Add runtime metrics
```

Milestone 3: contextual injection.

```text
1. Add visual retrieval gate
2. Inject max 3 visual lines into LLM context
3. Trace when visual memory was used
```

## Metrics To Track

Log these in research mode:

```text
vision_model_ms
frames_seen
frames_skipped
events_created
events_deduped
events_embedded
visual_context_injected
llm_ttft_with_vision
llm_ttft_without_vision
battery/thermal mode if available
```

Success condition:

```text
normal chat TTFT does not regress by more than 5-10%
vision context is injected only when useful
duplicate visual memories stay low
```

## Final Architecture

```text
Flutter camera/native frame source
  -> Rust vision worker
  -> detector backend
  -> event gate
  -> MemoryStore role="vision"
  -> Embedder only for accepted events
  -> retrieval trace
  -> LLM gets short visual context only when useful
```

This keeps AURA from becoming a giant synchronous pipeline. She gets senses, but the senses whisper instead of blocking her voice.

## Detailed Vision Pipeline & Perception Architecture

Here is the structured flow of the AURA perception and vision pipeline:

```text
      CAMERA / SCREEN
             │
             ▼
    Capture Manager
(Camera, Screen Capture, Accessibility)
             │
             ▼
      OpenCV Pipeline
Resize • Crop • Blur • Motion • Normalize
             │
             ▼
  ┌─────────────────────┐
  │ Parallel Processing │
  └─────────────────────┘
   │          │          │
   ▼          ▼          ▼
ML Kit       YOLO      MediaPipe
 OCR       Detection   Pose/Hands
   │          │          │
   └──────┬───┴──────────┘
          ▼
  Vision Interpreter
(Tiny Vision Language Model)
          │
          ▼
 Semantic Event Builder
          │
          ▼
{
  activity: "coding",
  app: "VS Code",
  objects: ["laptop","coffee"],
  text: "SyntaxError at line 52",
  confidence: 0.94
}
          │
          ▼
Visual Memory Store
          │
          ▼
 Decision Engine
          │
          ▼
    Main LLM (AURA)
```

### Pipeline Steps

#### Step 1 — Capture
Sources:
- 📷 Camera
- 🖥 Screen capture
- 📱 Android Accessibility API
- **Output:** Raw Image

#### Step 2 — OpenCV
OpenCV prepares the image for inference.
`Raw Camera` ➔ `Resize` ➔ `Denoise` ➔ `Correct Brightness` ➔ `Motion Detection` ➔ `Frame Ready`
*(Note: OpenCV never understands the image content itself, it only handles preprocessing and motion gating.)*

#### Step 3 — Parallel Vision Sensors
Instead of running one massive AI model, AURA runs specialized "experts" in parallel:
- **OCR:** Extracts text details (e.g. screen text showing `"SyntaxError line 52"` in `main.py`).
- **YOLO:** Detects primary objects (e.g. `"Laptop"`, `"Monitor"`, `"Coffee Mug"`, `"Phone"`).
- **MediaPipe:** Tracks posture, attention, and pose (e.g. `"Looking at monitor"`, `"Hands on keyboard"`, `"Sitting"`, `"Left hand moving"`).

#### Step 4 — Vision Interpreter
This is the most important step. It receives the raw sensor JSON:
```json
{
  "ocr": "SyntaxError line 52",
  "objects": ["laptop", "coffee"],
  "pose": "typing"
}
```
A tiny VLM (Vision-Language Model) interprets these facts into semantic context:
- **Activity:** Coding
- **Intent:** Debugging
- **Attention:** High
- **Confidence:** 96%
This converts raw labels like "laptop" and "coffee" into structured understanding: *"User is debugging Python code while drinking coffee."*

#### Step 5 — Event Builder
Converts everything into a structured semantic event:
```json
{
  "timestamp": "12:42",
  "activity": "coding",
  "subactivity": "debugging",
  "screen": "VS Code",
  "text": "SyntaxError",
  "objects": ["coffee", "laptop"],
  "importance": "medium",
  "confidence": 0.93
}
```
This is what gets stored in memory.

#### Step 6 — Visual Memory
Instead of storing heavy raw images, AURA stores compact semantic logs:
- `12:42` User debugging Python.
- `12:48` Compilation successful.
- `1:03` Switched to Chrome.
- `1:07` Watching Karpathy lecture.
This representation is tiny, searchable, and extremely LLM-friendly.

#### Step 7 — Decision Engine
When the user asks *"Why am I tired?"*, the Decision Engine retrieves:
`Visual Memory` ➔ `Coding continuously` ➔ `3 hours` ➔ `No breaks` ➔ `Coffee consumed`.
Now the main LLM can answer:
> *"You've been coding for about three hours without a meaningful break. A short walk or some water might help."*
There is no need to re-process old images.

---

### Event-Driven Optimization (Motion Gating)
To keep CPU usage and battery consumption low on mobile devices, AURA employs motion gating:

```text
30 FPS Camera
      │
      ▼
OpenCV Motion Detection
      │
      ▼
No motion?
      │
      ├── Yes → Skip frame
      │
      └── No
            │
            ▼
   Run OCR / YOLO / MediaPipe
            │
            ▼
   Vision Interpreter
            │
            ▼
   Create Semantic Event
```

---

### The Entire AURA Perception Pipeline
```text
               Sensors
                  │
 ┌────────────────┼────────────────┐
 │                │                │
Vision        Audio           Context
 │                │                │
 ▼                ▼                ▼
Vision      Speech Model    Calendar, Apps,
Pipeline       + VAD        Location, Time
 │                │                │
 └────────────────┼────────────────┘
                  ▼
         Event Normalization
                  ▼
           Memory Storage
                  ▼
          Decision Engine
                  ▼
              Main LLM
                  ▼
              AURA Response
```

