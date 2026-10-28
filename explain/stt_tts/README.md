# STT / TTS (Voice) Subsystem

## Overview
Voice I/O. STT (speech-to-text) and TTS (text-to-speech). Two backends: **Linux desktop** uses sherpa-onnx (Rust) + whisper fallback; **Android/iOS** uses platform-native speech_to_text + Android TTS MethodChannel. Feature flag `voice` gates the Rust sherpa path.

## STT

### `candle_LNN/aura_lnn/src/api/stt.rs` (Rust backend)
**Feature-gated:** `#[cfg(feature = "voice")]` → `voice_impl`, else stubs returning `false`.

**Static State:**
- `STT_ENGINE: OnceCell<Mutex<OnlineRecognizer>>` — sherpa streaming Zipformer (20M int8)
- `STT_STREAM: OnceCell<Mutex<OnlineStream>>`
- `STT_COMMITTED: OnceCell<Mutex<String>>` — accumulated endpoint text
- `STT_TOTAL_SAMPLES / STT_DECODE_TOTAL` — diagnostics

**Model:** `csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17` (int8), downloaded to `$XDG_DATA_HOME/aura_notebook/stt-20m-int8/`

**Functions:**

| Function | Purpose | Affects / Affected By |
|----------|---------|----------------------|
| `init()` | Load Zipformer (encoder/decoder/joiner/tokens) | Returns false if model absent → Dart falls back to whisper. Change search paths → update `resolve_model_dir`. |
| `push_audio(samples, sample_rate)` | Decode PCM chunk, return committed+partial text | Called from `stt_service.dart:_startRustListening`. Handles endpoint accumulation + reset. |
| `available()` | Is engine loaded? | Dart gating. |
| `reset_session()` | Clear committed buffer + reset stream | Called by Dart at start of each listening session. |
| `resolve_model_dir()` | Find model (env override → runtime cache → MODEL_DIR) | Matches `engine.rs:resolve_db_path` convention. |
| `runtime_cache_dir()` | `$XDG_DATA_HOME/aura_notebook/stt-20m-int8/` | Path convention. |
| `aura_stt_init/push_audio/available/reset_session` | Public bridge API | `api/mod.rs` re-export → frb generated → `stt.dart` in Flutter. |

**Endpointing:** rule1=2s trailing silence, rule2=1.2s breath, rule3=20s max utterance.

### `aura_notebook/lib/services/stt_service.dart` (Dart orchestrator)
**Key Struct: `AuraSTTService`** (singleton)

**State:**
- `_useRustStt` — using sherpa Rust path?
- `isMainApp` — affects permission flow
- `soundLevelNotifier` / `soundLevelStream` — RMS for UI + silence detection
- `isListeningNotifier`
- `_whisperServer` / `_whisperReady` — persistent Python whisper server (Linux fallback)
- `_recordProcess` / `_currentWavPath` — arecord WAV file
- `missingDependency` — surfaces setup errors

**Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `init()` | Linux: try rust_stt.auraSttInit. Mobile: speech_to_text.initialize. | Returns bool. |
| `startListening({onResult, onError})` | Dispatch: `_startRustListening` / `_startLinuxListening` / `_startMobileListening` | Called by `bar_brain.handleMicTap`. |
| `stopListening()` | Stop arecord / speech_to_text.stop | `bar_brain`. |
| `cancelListening()` | Stop + delete partial WAV | `bar_brain`. |
| `finalizeListening()` | Kill arecord, transcribe (Rust push or whisper WAV), return text | `bar_brain.doFinalize`. |
| `_ensureWhisperServer()` | Spawn persistent python whisper (base.en GPU) | Linux fallback path. |
| `_transcribeWav(wavPath)` | Send WAV to whisper stdin, await RESULT: line | Called by `finalizeListening`. |
| `_startLevelMonitor(gen)` | Separate raw arecord for RMS indicator | UI sound bars. |

**Flow:** `bar_brain.handleMicTap` → `stt.init()` → `stt.startListening` → silence/max timer → `finalizeListening` → text → `bar_brain.processUserPrompt`.

## TTS

### `candle_LNN/aura_lnn/src/api/tts.rs` (Rust backend)
**Feature-gated:** `#[cfg(feature = "voice")]` → `voice_impl`.

**Static State:**
- `TTS_ENGINE: OnceCell<Mutex<OfflineTts>>` — sherpa VITS (piper voice)
- `AUDIO_TX: OnceCell<Sender<AudioMsg>>` — rodio playback thread
- `TTS_TX: OnceCell<Sender<TtsJob>>` — generation thread
- `TTS_VOLUME: AtomicU32` — f32 bits, default 1.5 (boosted for piper audibility)
- `TTS_INIT_ATTEMPTED: AtomicBool`

**Model:** `en_US-lessac-medium.onnx` (preferred) / `en_US-amy-low.onnx`, with `tokens.txt` + `espeak-ng-data`. Pre-validated via `sherpa_compatible()` (ONNX metadata probe — raw piper exports would abort sherpa).

**Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `init()` | Find voice, probe sherpa_compatible, init OfflineTts + rodio audio + gen thread | Returns false → Dart falls back to Android channel / simulate. |
| `speak(text, speed, interrupt)` | Enqueue TtsJob → gen thread → AudioMsg::Play → rodio | Fire-and-forget. |
| `stop()` | AudioMsg::Stop to rodio sink | - |
| `set_volume(v)` | Store + push SetVolume to sink | `<0.0` = restore default 1.5. `0.0`=mute, `>1.0`=boost. |
| `available()` | Is TTS_ENGINE loaded? | - |
| `sherpa_compatible(model)` | ONNX metadata probe (sample_rate required by sherpa) | Prevents process abort. |

### `aura_notebook/lib/services/tts_service.dart` (Dart wrapper)
**Key Struct: `AuraTTSService`** (singleton)

**State:**
- `_useRustTts`, `_isPlaying`, `_activeSpeakCalls` (Android)
- `_volume` (Dart-side 0-1), `_muted`
- `_playbackTimer` — estimates duration (chars×65ms) since Rust speak is non-blocking
- `_androidTtsChannel` = `aura/tts` MethodChannel

**Functions:**

| Function | Purpose | Affects |
|----------|---------|---------|
| `init()` / `ensureReady()` | Try rust_tts.auraTtsInit. Android: warmup channel. | - |
| `speak(text, {onComplete, interrupt})` | Dispatch: `_speakRust` / `_speakAndroid` / `_simulateSpeech` | Called by `bar_brain`. |
| `_speakRust(text, interrupt, onComplete)` | auraTtsSpeak + playback timer | Desktop. |
| `_speakAndroid(text, interrupt, onComplete)` | invokeMethod 'speak', await onDone | Android. |
| `stop()` | rust_tts.auraTtsStop / channel stop | - |
| `setVolume/toggleMute/volumeUp/volumeDown` | + `_syncVolume()` | Affects Rust sink immediately. |
| `_cleanText(text)` | Strip brackets, emojis, swap !?;: to . | Piper voice phrasing. |
| `_estimateDurationMs(text)` | chars×65ms clamped 800-6000 | Drives isPlaying + onComplete. |

## Adding a Feature — What to Change

| Want to... | Change |
|-----------|--------|
| New STT model | `stt.rs:resolve_model_dir` search paths + `SttModelService.dart` download |
| New TTS voice | `tts.rs:VOICE_PREFS` list + `sherpa_compatible` check |
| Mobile-only STT | `stt_service.dart:_startMobileListening` (platform speech_to_text) |
| Streaming partials | `stt.rs:push_audio` returns committed+partial; change composition |
| Change voice speed | `tts_service.dart:_speakRust` speed param, or `tts.rs:TtsJob.speed` |
| New endpointing rule | `stt.rs:init` OnlineRecognizerConfig rule1/2/3 |
| Volume boost ceiling | `tts.rs:store_volume` clamp (0-3) + `tts_service.dart:_syncVolume` (×2.0) |
| Add wake word | `bar_brain.dart:_runWakeWordCycle` + `kWakeWordEnabled` flag |

## Data Flow

### STT
```
bar_brain.handleMicTap → stt.init() → stt.startListening
  [Rust] arecord raw → auraSttPushAudio → push_audio → decode → text
  [Linux fallback] arecord WAV → finalizeListening → whisper server → text
  [Mobile] speech_to_text.listen → result.recognizedWords
→ silence timer / max timer → finalizeListening → text → bar_brain.processUserPrompt
```

### TTS
```
bar_brain token stream → _flushSentences (Android) / onDone (desktop)
  → tts.speak(sentence)
    [Desktop] auraTtsSpeak → TTS_TX → gen thread → OfflineTts → AUDIO_TX → rodio Sink
    [Android] invokeMethod('speak') → platform TextToSpeech
```
