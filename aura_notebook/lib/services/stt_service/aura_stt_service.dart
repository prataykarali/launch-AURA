import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aura_notebook/src/rust/api/stt.dart' as rust_stt;

import '../bounded_work_bucket.dart';
import '../resource_guard_service.dart';

part 'init_extension.dart';
part 'linux_recording_start_extension.dart';
part 'linux_recording_finalize_extension.dart';
part 'whisper_extension.dart';
part 'mobile_recording_extension.dart';

// ── AuraSTTService ────────────────────────────────────────────────────────────
//
// Two paths — Linux (whisper via persistent Python server) and Mobile
// (speech_to_text).
//
// Linux path:
//   1. A persistent Python whisper server (whisper_server.py) is spawned once
//      and kept alive. It loads multilingual whisper-base onto the GPU one time and then
//      serves transcription requests via stdin/stdout (WAV path in → text out).
//   2. arecord captures audio to a temp WAV file while the user speaks.
//   3. RMS is computed from the PCM stdout for the mic-level indicator.
//   4. When finalizeListening() is called (silence detection or mic tap),
//      arecord is killed, the WAV is sent to the whisper server, and the
//      transcription is returned.
//
// Mobile: speech_to_text — kept verbatim.
//
// Public API unchanged: init/startListening/stopListening/cancelListening/
// finalizeListening, isListening, soundLevelNotifier/isListeningNotifier,
// missingDependency.

class AuraSTTService {
  AuraSTTService._();
  static final AuraSTTService instance = AuraSTTService._();

  bool _useRustStt = false;
  static bool isMainApp = false;

  // ── Mobile: platform-native speech recognition ────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  bool _initialized = false;
  String _lastMobileResult = '';
  bool _mobileFinalResultSeen = false;
  VoidCallback? _currentOnError;
  int _mobileListenGeneration = 0;

  // ── Linux: arecord → WAV + whisper server ─────────────────────────────────
  Process? _recordProcess;
  bool _isLinuxListening = false;
  int _recordGeneration = 0;

  // Temp WAV file for the current recording.
  String? _currentWavPath;

  // Raw PCM stdout subscription (for RMS only — no sherpa push needed).
  StreamSubscription<List<int>>? _sttStdoutSub;
  final BoundedWorkBucket<_RustAudioChunk> _rustAudioBucket =
      BoundedWorkBucket<_RustAudioChunk>(
        name: 'stt_audio_chunks',
        capacity: 12,
      );

  // ── Whisper server (persistent Python process) ───────────────────────────
  // Spawned once; kept alive for the app's lifetime so whisper-base.en stays
  // warm in GPU VRAM and every request takes ~0.5–1s instead of 35s cold load.
  Process? _whisperServer;
  bool _whisperReady = false;
  bool _whisperStarting = false;
  final List<Completer<String>> _whisperPending = [];
  static const int _kMaxWhisperPending = 1;
  StreamSubscription<String>? _whisperStdoutSub;
  StreamSubscription<String>? _whisperStderrSub;

  // ── Shared notifiers ──────────────────────────────────────────────────────
  // soundLevelNotifier exposes mic RMS (0.0–1.0) as both a ValueNotifier
  // (for widgets) and a Stream (for bar_brain's silence detection).
  final ValueNotifier<double> soundLevelNotifier = ValueNotifier<double>(0.0);
  final _soundLevelController = StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  // ── Missing-dependency surfacing ──────────────────────────────────────────
  String? _missingDependency;
  String? get missingDependency => _missingDependency;
  final ValueNotifier<String?> missingDependencyNotifier =
      ValueNotifier<String?>(null);

  bool get isListening => (_useRustStt || Platform.isLinux)
      ? _isLinuxListening
      : _speechToText.isListening;

  // ── startListening ────────────────────────────────────────────────────────
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    required VoidCallback onError,
  }) async {
    if (!ResourceGuardService.instance.shouldAcceptSensoryWork) {
      debugPrint('AuraSTT: health guard active — refusing new listen session');
      onError();
      return;
    }
    if (_useRustStt) {
      await _startRustListening(onResult: onResult, onError: onError);
      return;
    }
    if (Platform.isLinux) {
      await _startLinuxListening(onResult: onResult, onError: onError);
      return;
    }
    await _startMobileListening(onResult: onResult, onError: onError);
  }

  // ── stopListening ─────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    if (_useRustStt || Platform.isLinux) {
      _isLinuxListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      final p = _recordProcess;
      _killLinuxRecorder();
      if (p != null) {
        try {
          await p.exitCode.timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              try {
                p.kill(ProcessSignal.sigkill);
              } catch (_) {}
              return -1;
            },
          );
        } catch (_) {}
      }
      _currentWavPath = null;
      return;
    }
    _mobileListenGeneration++;
    try {
      if (_speechToText.isListening) await _speechToText.stop();
    } catch (e) {
      debugPrint('STT stop error: $e');
    } finally {
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      _currentOnError = null;
    }
  }

  // ── cancelListening ───────────────────────────────────────────────────────
  Future<void> cancelListening() async {
    if (_useRustStt || Platform.isLinux) {
      _isLinuxListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      _killLinuxRecorder();
      // Delete the partial WAV.
      if (_currentWavPath != null) {
        try {
          await File(_currentWavPath!).delete();
        } catch (_) {}
        _currentWavPath = null;
      }
      return;
    }
    _mobileListenGeneration++;
    try {
      if (_speechToText.isListening) await _speechToText.cancel();
    } catch (e) {
      debugPrint('STT cancel error: $e');
    } finally {
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      _currentOnError = null;
    }
  }

  // ── finalizeListening ─────────────────────────────────────────────────────
  //
  // Stop arecord (finalizes the WAV), send WAV to whisper server, return text.
  Future<String> finalizeListening() async {
    if (_useRustStt) return _finalizeRustListening();
    if (Platform.isLinux) return _finalizeLinuxListening();

    // Mobile: stop() normally causes Android's recognizer to emit one last
    // final result. Keep the current listen generation alive briefly so that
    // callback is accepted instead of being discarded as stale.
    final stopGen = _mobileListenGeneration;
    try {
      if (_speechToText.isListening) await _speechToText.stop();
    } catch (e) {
      debugPrint('STT finalize stop error: $e');
    }
    final deadline = DateTime.now().add(
      Platform.isAndroid
          ? const Duration(milliseconds: 1600)
          : const Duration(milliseconds: 700),
    );
    while (stopGen == _mobileListenGeneration &&
        !_mobileFinalResultSeen &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (stopGen == _mobileListenGeneration) {
      _mobileListenGeneration++;
    }
    isListeningNotifier.value = false;
    soundLevelNotifier.value = 0.0;
    _currentOnError = null;
    return _lastMobileResult;
  }

  Future<void> dispose() async {
    await cancelListening();
    await _whisperStdoutSub?.cancel();
    _whisperStdoutSub = null;
    await _whisperStderrSub?.cancel();
    _whisperStderrSub = null;
    final server = _whisperServer;
    _whisperServer = null;
    _whisperReady = false;
    _whisperStarting = false;
    _killProcess(server);
    await _soundLevelController.close();
  }

  void _clearMissingDependency() {
    if (_missingDependency == null) return;
    _missingDependency = null;
    missingDependencyNotifier.value = null;
  }

  // Helper to kill a process with SIGTERM, then SIGKILL fallback after 200ms
  void _killProcess(Process? p) {
    if (p == null) return;
    try {
      p.kill(ProcessSignal.sigterm);
      Timer(const Duration(milliseconds: 200), () {
        try {
          p.kill(ProcessSignal.sigkill);
        } catch (_) {}
      });
    } catch (_) {}
  }
}
