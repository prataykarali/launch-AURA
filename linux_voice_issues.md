# Linux Voice (STT & TTS) Diagnostic Report

This document outlines the architectural issues, logic bugs, and system-level conflicts detected in the Speech-to-Text (STT) and Text-to-Speech (TTS) subsystems under Linux for AURA.

---

## 1. Text-to-Speech (TTS) Diagnostic Findings

### A. Missing `sample_rate` Metadata in Piper ONNX Models (Critical)
*   **Location:** [tts.rs (line 39-103)](file:///home/pratay-karali/launch-AURA/AURA-Proj/candle_LNN/aura_lnn/src/api/tts.rs#L39-L103) - `sherpa_compatible`
*   **Root Cause:** The `sherpa-onnx` VITS parser (specifically the C++ underlying layer) hard-requires that VITS models contain the `sample_rate` attribute embedded inside the ONNX graph's custom metadata properties (`metadata_props`). Raw HuggingFace Piper exports (e.g., `en_US-lessac-medium.onnx` and `en_US-amy-low.onnx` installed via `setup_voice_linux.sh`) only specify the sample rate in the `.json` sidecar.
*   **Symptom:** The ORT metadata check in `sherpa_compatible` fails and logs `metadata probe FAIL`. It skips the candidate model. Since all available local voice models are skipped, `aura_tts_init()` returns `false`, causing the Dart layer to disable local TTS support.
*   **Impact:** Offline local TTS is disabled on Linux.

### B. Speech Simulation Fallback (Silent Failure)
*   **Location:** [tts_service.dart (line 493-504)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/tts_service.dart#L493-L504) - `_simulateSpeech`
*   **Root Cause:** When `_useRustTts` is `false` (due to the above compatibility failure) and the online EdgeTTS service is unavailable or offline, the app falls back to `_simulateSpeech`.
*   **Symptom:** `_simulateSpeech` merely starts a timer based on the text length and fires `onComplete` without emitting any audio or displaying a prominent error message to the user.
*   **Impact:** The user experiences a silently failed voice assistant that displays text but never speaks.

---

## 2. Speech-to-Text (STT) Diagnostic Findings

### A. Dead / Unreachable Rust STT Initialization Block
*   **Location:** [stt_service.dart (line 92-117)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/stt_service.dart#L92-L117) - `init`
*   **Root Cause:** The initialization logic contains a duplicate check for `Platform.isLinux`:
    ```dart
    // Linux: use whisper only (sherpa is unstable)
    if (Platform.isLinux) {
      _initialized = true;
      unawaited(_ensureWhisperServer());
      return true; // <--- Returns early here
    }

    // Android: try Rust sherpa STT first, then fall back to whisper
    if (Platform.isLinux) { // <--- Duplicate block, never reached
      ...
    }
    ```
    The second block (which initializes Rust-side `sherpa-onnx` STT via `auraSttInit()`) is dead code. The comment suggests the second check was intended to target `Platform.isAndroid`.
*   **Impact:** Clean integration and runtime loading of the Rust Zipformer model is bypassed on Linux.

### B. Concurrent `arecord` Process Spawning (ALSA EBUSY Risk)
*   **Location:** [stt_service.dart (line 507-597)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/stt_service.dart#L507-L597) - `_startLinuxListening` & `_startLevelMonitor`
*   **Root Cause:** To support both recording audio to a WAV file and displaying a live sound level/waveform indicator, the Linux STT service spawns two separate, concurrent `arecord` subprocesses:
    1.  `arecord -q -t wav -f S16_LE -r 16000 -c 1 /tmp/aura_stt_...wav`
    2.  `arecord -q -t raw -f S16_LE -r 16000 -c 1`
*   **Symptom/Impact:** On Linux configurations without a shared audio server (PulseAudio/PipeWire) or when ALSA is locked by another device, the second process fails immediately with an `EBUSY` error (Device or resource busy). This results in a frozen mic-level visual indicator or recording failures.

### C. Zombie Whisper Server Processes
*   **Location:** [stt_service.dart (line 231-304)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/stt_service.dart#L231-L304) - `_ensureWhisperServer`
*   **Root Cause:** The Python process (`whisper_server.py`) is started as a child process of the Flutter app. If the Flutter application crashes or is forcefully terminated (e.g. via `SIGKILL` or system crash), the child process remains alive in the background.
*   **Impact:** A zombie `python3` process consumes system resources and keeps the GPU memory (VRAM) allocated for `whisper-base.en` until killed manually.

### D. Startup Latency / Timeout Risks
*   **Location:** [stt_service.dart (line 307-317)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/stt_service.dart#L307-L317) - `_transcribeWav`
*   **Root Cause:** The `whisper_server.py` takes ~8–15 seconds to load PyTorch, Whisper libraries, and transfer the `base.en` model to the GPU.
*   **Symptom:** If a user initiates speech input immediately on application launch, the transcription request waits on `_transcribeWav`. The transaction can hit the 15-second deadline, resulting in timeout failures.
