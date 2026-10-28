# Bar UI Subsystem

## Overview
The bar layer is the smallest, fast, push-to-talk UI overlay in the middle of the screen. It handles:
- Quick question answering (1-2 sentence max)
- Voice interaction (push-to-talk)
- Proactive (RL bandit) events
- Volume/mute
- State sharing across the multi-window bar windows (desktop overlays)

## Core Architecture
**Flutter Package:** `aura_notebook/lib/bar/` contains:

| File | Purpose | Affects |
|------|---------|---------|
| `bar_state.dart` | Enum: IDLE, LISTENING, PROCESSING, SPEAKING, PROACTIVE, LEARNING | UI controller for bar window state |
| `bar_controller.dart` | Manages position/size overlays (window manager side effect) | Physical bar placement |
| `bar_root_widget.dart` | Top-level bar widget, hosts main bar content | Root of bar surface |
| `bar_window_app.dart` | Bar window setup (bar shell hides toolbar, etc.) | Container for bar windows |
| `bar_window_manager.dart` | Desktop multi-window IPC (bar <-> main app) | Window creation / state sync |
| `bar_multi_window_service.dart` | Cross-process communication (bar <-> bar) | For shared state across overlay windows |
| `bar_particles.dart` | Visual "closed mouth" waveform on idle (cool micro-interaction) | Idle bar appearance |
| `bar_waveform.dart` | Animated waveform on speaking / processing | Visual feedback |
| `bar_buttons.dart` | Mic/record button (push-to-talk) | Interaction element |
| `bar_tray_icon.dart` | System tray icon (Linux) | Platform integration |
| `bar_shell.dart` | Platform-specific window shell (Linux tray, macOS menu) | Platform abstraction |
| `bar_constants.dart` | UI constants (colors, spacing, fonts, bar length limits) | Sizing/layout/styling |
| `aura_bar.dart` | Main bar UI (AURA label + pulse animation + pill)|
| `aura_bar_app.dart` | MaterialApp for bar window |

## Key Classes

### `AuraBarBrain` (`aura_notebook/lib/services/bar_brain.dart`)
Manages everything the bar does:

| State | Variables | Purpose |
|-------|------------|---------|
| `isProcessing` | `_isProcessing`, `_processingStartedAt` | User prompt is active |
| `currentState` | `_state`, `_updateBar()`, `_streamUpdate()` | Current bar UI state |
| `engineReady` | `engineReady`, `_flushPending()` | Connected to Rust engine |
| `soundLevel` | `soundLevelNotifier`, `soundLevelStream` | Mic volume level for waveform |
| `response` | `_currentResponse`, `_sentenceBuffer` | Generated text |

**Core Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `handleMicTap()` | Push-to-talk: start/stop listening | Origin of user prompts |
| `processUserPrompt()` | Engine call with [BRIEF] suffix for bar queries | Short-answer mode |
| `handleProactiveTrigger()` | RL bandit event → bar overlay | Proactive events |
| `speakResponse()` | Direct barTTS (used for internal prompts) | Bar-first TTS |
| `cancelCurrentOps()` | Stop everything → reclaim lock | Emergency stop |
| `syncState()` | Receive state from overlay + main app | Shared state |
| `_runGeneration()` | Stream engine response, split sentences (Android) | Core of user + proactive turns |

**State Machine:**
- **IDLE** → LISTENING (handleMicTap) → PROCESSING → SPEAKING ↔ IDLE
- **IDLE** → PROACTIVE (RL trigger) → SPEAKING → IDLE

**Key Behaviors:**
- **2s max-listen cap** (`_maxListenTimer`)
- **Silence detection** (auto-finalize after quiet)
- **Brain stale override** (30s processing reclaims lock)
- **Queued prompt** (last-writer-wins)
- **Amnesia guard** in LLM engine (prevents injection of denials)

## Multi-Window IPC

### `AuraBarMultiWindowService` (`aura_notebook/lib/bar/bar_multi_window_service.dart`)

| Function | Purpose | Affected By |
|----------|---------|-------------|
| `showOrCreateBar()` | Opens overlay window (desktop) or brings existing to front (macOS/Windows) | Bar controller |
| `sendState()` | Flutter MethodChannel → BarNative → cross-process libsend → bar\win32(/bar_shell) | State synchronization |
| `registerMessageHandler()` | Listen to bar window control (minimize/maximize/close) | Platform windows |

**Channels:**
- `aura/bar-to-main` → bar → main app
- `aura/main-to-bar` → main app → bar
- `aura/bar-to-bar` → bar win1 → bar win2 (only desktop)

**Lifetime:** bar windows run as separate Flutter Engine instances (kept in the same process on desktop). Window manager keeps position/size consistent across logins.

## Interface Surface

**Bar Brain public API:**
```dart
// Voice
handleMicTap({userInitiated = true})
// Sync
engineReady, syncState(state, message)
// Proactive
showProactiveOverlay(label)
// Output
currentResponse, currentState, isProcessing
// Volume
volume, volumeUp, volumeDown, toggleVolume
// TTS
isMuted
// Paraphrase
handleScrollingInteraction(x, y)
```

**Bar State Enum (`bar_state.dart`):**
```dart
enum BarState {
  idle,          // Neutral, closed-mouth pill
  listening,     // Open pill, ambient mic (not used)
  processing,    // Listening → "Transcribing..." → "Just a moment..."
  speaking,      // Waveform visible, AURA is talking (response)
  proactive,     // Cute mini-event (morning/afternoon greeting)
  learning,      // "Thinking..." (proactive prompt)
}
```

## Adding a Feature — What to Change

| Want to... | Change |
|-----------|--------|
| New UI element in bar | `aura_bar.dart` + constants + bar_root_widget layout |
| Custom bar color / theme | `bar_constants.dart` : themeData / barColors |
| Bar button icon | `bar_buttons.dart` : icons/assets |
| Bar length policy change | `bar_brain.processUserPrompt()` word/char limits |
| Bar window size | `bar_controller.dart` : platform resize logic |
| Bar greeting message | `handleProactiveTrigger`: add `kMorningGreeting` |
| Bar cooldown on user typing | `userIsTyping`, `lastUserInteraction` guards in proactive handling |
| Bar clipboard read | `bar_brain.clipboardSupport`? → Windows/macOS native |

## Data Flow

```
User touches mic button:
  aura_bar_brain.handleMicTap() → (isIdle, quiet) → auraSTT.startListening
    [Linux] arecord raw → sttService._startRustListening → auraSttPushAudio → recognize → text
    [Android] speech_to_text.start
  2s max timer + silence detection → finalizeListening → text → auraBarBrain.processUserPrompt → ([BRIEF] suffix) → TX channel → worker → process_chat → stored memory → generate → stream → barSpeech
    [Desktop] TTS.speak(sentence) → speakResponse → AuraBarMultiWindowService.sendState → bar window waveform + text
  bar -> main app messages for scrolling / coordination

RL trigger:
  Scheduler fires → bar.showProactiveOverlay(label) → AuraBarMultiWindowService.showOrCreateBar
    → barBrain.handleProactiveTrigger(label) → "[Internal: ...]" prompt → engine → TTS.speak => proactive message
```
