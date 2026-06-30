part of 'aura_stt_service.dart';

extension _AuraSTTServiceLinuxFinalize on AuraSTTService {
  Future<String> _finalizeRustListening() async {
    _isLinuxListening = false;
    isListeningNotifier.value = false;
    soundLevelNotifier.value = 0.0;

    final p = _recordProcess;
    _killLinuxRecorder();

    if (p != null) {
      try {
        await p.exitCode.timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            try {
              p.kill(ProcessSignal.sigkill);
            } catch (_) {}
            return -1;
          },
        );
      } catch (_) {}
    }

    try {
      return await rust_stt.auraSttPushAudio(samples: [], sampleRate: 16000);
    } catch (e) {
      debugPrint('AuraSTT Rust finalize error: $e');
      return '';
    }
  }

  Future<String> _finalizeLinuxListening() async {
    _isLinuxListening = false;
    isListeningNotifier.value = false;
    soundLevelNotifier.value = 0.0;

    final wavPath = _currentWavPath;
    _currentWavPath = null;

    final p = _recordProcess;
    _killLinuxRecorder();

    if (p != null) {
      try {
        await p.exitCode.timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            try {
              p.kill(ProcessSignal.sigkill);
            } catch (_) {}
            return -1;
          },
        );
      } catch (_) {}
    }

    if (wavPath == null || !File(wavPath).existsSync()) {
      debugPrint('STT Linux: no WAV file to transcribe');
      return '';
    }

    // Check WAV file is non-trivially small (< 32KB = essentially silence).
    final fileSize = await File(wavPath).length();
    if (fileSize < 32768) {
      debugPrint(
        'STT Linux: WAV too small ($fileSize bytes) — skipping whisper',
      );
      try {
        await File(wavPath).delete();
      } catch (_) {}
      return '';
    }

    debugPrint(
      'STT Linux: transcribing WAV ($fileSize bytes) with whisper...',
    );
    String text = '';
    try {
      text = await _transcribeWav(wavPath);
    } finally {
      try {
        await File(wavPath).delete();
      } catch (_) {}
    }

    debugPrint('STT Linux: whisper → "$text"');
    return text;
  }
}
