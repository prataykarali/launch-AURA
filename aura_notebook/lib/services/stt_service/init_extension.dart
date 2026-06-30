part of 'aura_stt_service.dart';

// ── init ──────────────────────────────────────────────────────────────────
extension AuraSTTServiceInit on AuraSTTService {
  Future<bool> init() async {
    if (_initialized) return true;

    // Linux defaults to Whisper because the small sherpa model hallucinates.
    // Set AURA_STT_BACKEND=sherpa to exercise the Rust streaming path.
    if (Platform.isLinux) {
      _initialized = true;
      final backend = Platform.environment['AURA_STT_BACKEND']?.toLowerCase();
      if (backend == 'sherpa' || backend == 'rust') {
        try {
          _useRustStt = await rust_stt.auraSttInit();
          if (_useRustStt) {
            debugPrint('AuraSTT: Rust sherpa STT initialized by env override');
            return true;
          }
        } catch (e) {
          debugPrint('AuraSTT: Rust sherpa STT init failed: $e');
        }
      }
      _useRustStt = false;
      await _ensureWhisperServer().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[AURA_WHISPER] startup still warming after 8s');
        },
      );
      return _missingDependency == null;
    }

    // Android / macOS / Windows: use platform speech_to_text (Rust STT uses
    // arecord which is Linux-only). Skip Rust init to avoid false failures.
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows) {
      _useRustStt = false;
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          final granted = await Permission.microphone.request().isGranted;
          if (!granted) {
            debugPrint(
              'AuraSTT: Microphone permission not granted during init()',
            );
            _missingDependency = 'microphone-permission';
            missingDependencyNotifier.value = _missingDependency;
            return false;
          }
        }
        final ok = await _speechToText.initialize(
          onError: (errorNotification) {
            debugPrint('STT Error: $errorNotification');
            // Reset _initialized on non-transient errors to allow retry
            if (errorNotification.errorMsg != 'error_no_match' &&
                errorNotification.errorMsg != 'error_speech_timeout') {
              _initialized = false;
            }
            isListeningNotifier.value = false;
            soundLevelNotifier.value = 0.0;
            if (_lastMobileResult.trim().isNotEmpty &&
                (errorNotification.errorMsg == 'error_no_match' ||
                    errorNotification.errorMsg == 'error_speech_timeout')) {
              _mobileFinalResultSeen = true;
            } else {
              _currentOnError?.call();
            }
            _currentOnError = null;
          },
          onStatus: (status) {
            debugPrint('STT Status: $status');
            isListeningNotifier.value = _speechToText.isListening;
            if (!_speechToText.isListening) soundLevelNotifier.value = 0.0;
          },
        );
        _initialized = ok; // only mark initialized if it actually succeeded
        if (_initialized) {
          _clearMissingDependency();
          debugPrint('AuraSTT: Platform speech_to_text initialized');
        } else {
          debugPrint(
            'AuraSTT: speech_to_text.initialize() returned false '
            '(permission denied or engine unavailable)',
          );
          _missingDependency = 'speech-recognizer';
          missingDependencyNotifier.value = _missingDependency;
        }
        return _initialized;
      } catch (e) {
        debugPrint('STT Init failed: $e');
        _initialized = false; // allow retry
        _missingDependency = 'speech-recognizer';
        missingDependencyNotifier.value = _missingDependency;
        return false;
      }
    }

    return false;
  }
}
