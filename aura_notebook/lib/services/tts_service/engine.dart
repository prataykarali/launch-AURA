part of 'tts_service.dart';

// ── AuraTTSService engine mixin (Android platform + Rust offline) ──────────
extension _AuraTTSServiceEngine on AuraTTSService {
  Future<bool> _warmupAndroidTts() async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      final ready = await AuraTTSService._androidTtsChannel.invokeMethod<bool>('warmup');
      if (ready == true) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return await AuraTTSService._androidTtsChannel.invokeMethod<bool>('warmup') == true;
  }

  Future<void> _syncVolume() async {
    if (Platform.isAndroid) {
      if (_muted) {
        try {
          await AuraTTSService._androidTtsChannel.invokeMethod<bool>('stop');
        } catch (_) {}
      }
      return;
    }
    if (!_useRustTts) return;
    try {
      final gain = _muted ? 0.0 : (_volume * 2.0).clamp(0.0, 3.0);
      await rust_tts.auraTtsSetVolume(volume: gain);
    } catch (e) {
      debugPrint('AuraTTS: auraTtsSetVolume error (non-fatal): $e');
    }
  }

  Future<void> _speakRust(
    String text,
    bool interrupt,
    VoidCallback? onComplete,
  ) async {
    try {
      await rust_tts.auraTtsSpeak(text: text, speed: 1.0, interrupt: interrupt);
      _playbackTimer?.cancel();
      final durationMs = _estimateDurationMs(text);
      _playbackTimer = Timer(Duration(milliseconds: durationMs), () {
        _isPlaying = false;
        onComplete?.call();
      });
    } catch (e) {
      debugPrint('AuraTTS Rust error: $e');
      _isPlaying = false;
      onComplete?.call();
    }
  }

  Future<void> _enqueueAndroidSpeak(
    String text,
    bool interrupt,
    VoidCallback? onComplete, {
    double volume = 1.0,
  }) {
    if (interrupt) {
      _androidSpeakChain = Future<void>.value();
      return _speakAndroid(text, true, onComplete, volume: volume);
    }

    // Don't chain streaming chunks — Android TTS has its own native queue.
    // Chaining forced each chunk to wait for the previous one's estimated
    // duration timer before even being sent, causing TTS to freeze mid-reply.
    return _speakAndroid(text, false, onComplete, volume: volume);
  }

  Future<void> _speakAndroid(
    String text,
    bool interrupt,
    VoidCallback? onComplete, {
    double volume = 1.0,
  }) async {
    try {
      if (interrupt) {
        await stop();
      }
      _activeSpeakCalls++;
      _isPlaying = true;
      final ok = await AuraTTSService._androidTtsChannel.invokeMethod<bool>('speak', {
        'text': text,
        'volume': volume,
      });
      if (ok != true) {
        debugPrint('AuraTTS Android: platform speak() reported failure');
      }
      // The platform channel returns as soon as the utterance is queued, but the
      // actual audio continues. Hold the playing flag for the estimated duration
      // so proactive triggers don't overlap speech that is still in progress.
      _playbackTimer?.cancel();
      _playbackTimer = Timer(Duration(milliseconds: _estimateDurationMs(text)), () {
        _activeSpeakCalls = (_activeSpeakCalls - 1).clamp(0, 999);
        if (_activeSpeakCalls == 0) {
          _isPlaying = false;
        }
        onComplete?.call();
      });
    } catch (e) {
      debugPrint('AuraTTS Android: speak error: $e');
      _activeSpeakCalls = (_activeSpeakCalls - 1).clamp(0, 999);
      if (_activeSpeakCalls == 0) {
        _isPlaying = false;
      }
      onComplete?.call();
    }
  }

  void _reportMissingOfflineTts(String text, VoidCallback? onComplete) {
    _missingDependency = 'sherpa-tts';
    _lastProvider = 'unavailable';
    missingDependencyNotifier.value = _missingDependency;
    _playbackTimer?.cancel();
    debugPrint(
      'AuraTTS: no offline desktop TTS available and online fallback failed; '
      'not simulating speech for "${text.length > 48 ? '${text.substring(0, 48)}...' : text}"',
    );
    _isPlaying = false;
    onComplete?.call();
  }

  int _estimateDurationMs(String text) => (text.length * 65).clamp(800, 6000);

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[\u2600-\u27BF]'), '')
        .replaceAll(RegExp(r'[\uD800-\uDBFF][\uDC00-\uDFFF]'), '')
        .replaceAll('!', '.')
        .replaceAll('?', '.')
        .replaceAll(';', '.')
        .replaceAll(':', '.')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
