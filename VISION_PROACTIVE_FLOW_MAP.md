# AURA Vision + Proactive Flow Map

## Vision Pipeline (Headless — No Camera Window)

```
User says "what do you see?"
        │
        ▼
┌─────────────────────────────────┐
│ bar_brain_prompt.dart           │
│ shouldTriggerCapture(text)      │
│ → BarState.watching             │
│ → "AURA is watching..."         │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│ VisionService.captureNow()      │
│ → scrot screenshot (Tier 1)     │
│ → _activityFromWindowTitle()    │
│   → coding / browsing / video   │
│   → terminal / gaming / idle    │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│ Motion Gate (luminance diff)    │
│ → skip if static (80% saved)    │
│ → motion streak > 2 → active    │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│ Rust: start_webcam_thread()     │
│ HEADLESS (no minifb window)     │
│ Camera: /dev/video0 640x480     │
└──────────┬──────────────────────┘
           │
     Model Rotation (1 at a time)
     ┌─────────┬─────────┬─────────┐
     │ Cycle 1 │ Cycle 2 │ Cycle 3 │
     │  YOLO   │  Pose   │ Emotion │
     │ objects │ gesture │  FER+   │
     │  v8n    │  v8n    │ ferplus │
     └────┬────┴────┬────┴────┬────┘
          │         │         │
          ▼         ▼         ▼
     ┌─────────────────────────────┐
     │ aura_process_vision()       │
     │ → VisionGate (cooldown 3s)  │
     │ → store_visual_event()      │
     │ → set_latest_webcam_scene() │
     └──────────┬──────────────────┘
                │
       ┌────────┴────────┐
       ▼                 ▼
  Gesture detected?   Object detected?
       │                 │
       ▼                 ▼
  GESTURE_FOR_DART   VisionEvent stored
  → Dart polls       → proactive context
  → "Hey AURA!"      → "I see a person..."
  greeting           → memory_notes

Auto-close: watch session expires (20s)
or bar hidden → stop_webcam_thread()
```

## Proactive Pipeline

```
ProactiveScheduler (30s debug / 15-30min prod)
        │
        ├─ 0. Schedule Notes Check
        │   → auraGetProactiveContext()
        │   → parse "Schedule request: remind me to X"
        │   → fire as schedule_reminder trigger
        │
        ├─ 1. Clock Triggers (hour-based)
        │   → 8AM  → morning_greeting
        │   → 2PM  → afternoon_checkin
        │   → 8PM  → evening_winddown
        │
        ├─ 2. Idle Trigger (10 min silence)
        │   → idle_checkin
        │
        ├─ 3. Bandit RL (epsilon-greedy)
        │   → auraCheckProactive() → Rust
        │   → 8 triggers in DB
        │   → softmax over engagement_score
        │   → 15% exploration / 85% exploit
        │
        ├─ 4. Natural Context (vision/speech)
        │   → sustained activity 5 min → nudge
        │   → "I'm tired/stuck/stressed" → support
        │   → stuck screen (OCR 10x same) → help
        │
        └─ 5. Debug Mode (60s cycle)
            → force overlay popup
            → force auraCheckProactive()
            → rotating debug labels

All triggers → handleProactiveTrigger()
        │
        ▼
┌─────────────────────────────┐
│ _buildProactivePrompt()     │
│ → trigger_label + type      │
│ → observed context          │
│ → memory_context (facts)    │
│ → "Reply SILENT if no need" │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ _runGeneration()            │
│ → auraChat(prompt)          │
│ → LLM generates response    │
│ → TTS speaks                │
│ → Bar shows response        │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Outcome tracking            │
│ → user engages → reward +   │
│ → user ignores → reward -   │
│ → record_engagement()       │
│ → bandit learns             │
└─────────────────────────────┘
```

## Model Loading Sequence (1-at-a-time)

```
Phase 1: YOLO v8n (objects)
  ↓ 900ms inference cycle
Phase 2: YOLO v8n-pose (gestures)
  ↓ lazy-load on first Pose cycle
  ↓ 900ms inference cycle
Phase 3: FER+ (emotions)
  ↓ lazy-load on first Emotion cycle
  ↓ quick YOLO first (for face boxes)
  ↓ 900ms inference cycle
Phase 1 again: YOLO v8n (objects)
  ...

Memory: only 1 ONNX session active per cycle
  YOLO:  12 MB
  Pose:  13 MB
  FER+:  33 MB
  Total if all at once: 58 MB → crash risk
  Rotation: max 33 MB at any time
```
