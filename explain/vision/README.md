# Vision Subsystem

## Overview
The vision subsystem is fully active. A local webcam capture loop (`webcam.rs`) captures frames from `/dev/video0` (or `/dev/video1`) on Linux, runs local YOLOv8 object detection (`yolov8n.onnx`), and performs lightweight frame-differencing motion analysis for gesture detection. Object detection and gesture results are converted to text facts prefixed `vision:`, filtered by confidence and cooldown in `VisionGate`, and stored in the SQLite `facts` table.

## Core Files

### `candle_LNN/aura_lnn/src/vision/webcam.rs`
**Webcam Loop & Gesture Analyzer**
- Captures frames from Linux V4L devices at 30 FPS.
- Runs lightweight frame-differencing motion analysis (sampling pixels for zero CPU overhead) to detect gestures (e.g., waving).
- Runs local YOLOv8 ONNX inference every 900ms, and appends a `"user waving / hand gesture"` detection if motion was detected.
- Renders a live debugging view with bounding boxes and labels via `minifb`.

### `candle_LNN/aura_lnn/src/vision/mod.rs` (barrel)
Re-exports: `VisionDetection`, `VisionEvent`, `VisionGate`, `get_recent_visual_context`, `store_visual_event`.

### `candle_LNN/aura_lnn/src/vision/events.rs`
**Structs:**

| Struct | Fields | Purpose |
|--------|--------|---------|
| `VisionDetection` | `label`, `confidence`, `bbox: Option<[f32;4]>` | Single detection from a model. |
| `VisionEvent` | `text`, `timestamp`, `importance` | Aggregated event for storage. |

**Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `detections_to_event_text(detections)` | Build natural-language "vision: X and Y visible" text | Produces the `vision:` fact text. Change wording here → affects how memory/LLM reads it. |
| `VisionEvent::new(detections, importance)` | Construct event (calls detections_to_event_text, stamps ts) | `gate::process_detections`. |

### `candle_LNN/aura_lnn/src/vision/gate.rs`
**Key Struct: `VisionGate`** (`last_seen: HashMap<String, i64>`, `cooldown_secs`, `min_confidence`, `min_importance`)

| Function | Purpose | Affects |
|----------|---------|---------|
| `new(cooldown_secs, min_confidence, min_importance)` | Configure gate | Construction. |
| `process_detections(detections)` | Filter by confidence, dedup by cooldown, return VisionEvent if any pass | Feeds into `store_visual_event`. Change thresholds → affects event fire rate. |

**Logic:** confidence ≥ min → cooldown check per label → importance (currently static 0.6) ≥ min → emit.

### `candle_LNN/aura_lnn/src/vision/store.rs`
| Function | Purpose | Affects |
|----------|---------|---------|
| `store_visual_event(store, event)` | `store.insert_fact(event.text)` | Writes to `facts` table with `vision:` prefix. This means vision facts are ALWAYS injected into chat context via get_facts_strings — same path as identity facts. |
| `get_recent_visual_context(store, limit)` | SELECT fact WHERE LIKE 'vision:%' | Read path. Matches the prefix convention. |

## Integration Points

| Component | Depends On | Affects |
|-----------|------------|---------|
| `VisionGate` | `VisionEvent`, chrono | Downstream store_visual_event |
| `store_visual_event` | `MemoryStore.insert_fact` | `facts` table → `get_facts_strings` → chat context |
| `get_recent_visual_context` | `MemoryStore.acquire_conn` | UI/queries wanting only vision facts |
| Future: vision embedder | `Embedder` trait in `embed.rs` | Would need separate dim + table (NOT vec_memory) to avoid cosine collision with text |

## Adding a Feature — What to Change

| Want to... | Change |
|-----------|--------|
| Plug a real detector (YOLO/CLIP) | New file `vision/detector.rs` returning `Vec<VisionDetection>`, feed `VisionGate::process_detections` |
| Different cooldown per label | `VisionGate.last_seen` → `HashMap<String, (i64, i64)>` (last_fired + per-label cooldown) |
| Importance from detection (not static) | `gate::process_detections` importance calc |
| Separate vision memory | New table in `store/mod.rs`; stop prefixing `vision:` into facts; new embedder impl (text vs vision dims must differ) |
| Visual RAG | Clone `store::search_relevant` for vision table; new BgeTextEmbedder alternative implementing `Embedder` |
| Stop vision polluting identity facts | Either tag facts with `kind` column or stop using `insert_fact` — both touch `store/mod.rs` schema + `engine.rs:process_chat` facts selection |

## Data Flow

```
Detector → Vec<VisionDetection>
  → VisionGate.process_detections [filter confidence + cooldown dedup]
  → Option<VisionEvent>
  → store_visual_event(store, event)
      → MemoryStore.insert_fact("vision: laptop and mug visible")
  → (later) get_facts_strings() injects into LLM context alongside identity facts
```

Note: because vision and identity share the `facts` table (only the `vision:` prefix distinguishes them), `process_chat`'s amnesia guard and `build_grounded_reply` may surface vision text in identity queries. Separate `kind` column is the clean fix.
