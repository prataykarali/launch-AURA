part of 'bar_brain.dart';

extension AuraBarBrainWakeWord on AuraBarBrain {
  void startWakeWordListener() {
    if (!AuraBarBrain.kWakeWordEnabled) return; // passive listening off — push-to-talk only
    if (_wakeWordEnabled &&
        (_isWakeWordListening || _wakeWordRestartTimer?.isActive == true)) {
      return;
    }
    _wakeWordEnabled = true;
    _runWakeWordCycle();
  }

  void stopWakeWordListener() {
    _wakeWordEnabled = false;
    _isWakeWordListening = false;
    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = null;
    AuraSTTService.instance.stopListening();
  }

  Future<void> _runWakeWordCycle() async {
    if (!_wakeWordEnabled) return;
    if (_isWakeWordListening) return;

    if (Platform.isAndroid || Platform.isIOS) {
      final granted = await Permission.microphone.isGranted;
      if (!granted) {
        debugPrint(
          '[WAKE WORD] Microphone permission not granted — disabling.',
        );
        _wakeWordEnabled = false;
        _isWakeWordListening = false;
        _wakeWordRestartTimer?.cancel();
        _wakeWordRestartTimer = null;
        return;
      }
    }

    if (_isProcessing ||
        AuraSTTService.instance.isListening ||
        AuraTTSService.instance.isPlaying) {
      _wakeWordRestartTimer?.cancel();
      _wakeWordRestartTimer = Timer(
        const Duration(seconds: 5),
        _runWakeWordCycle,
      );
      return;
    }

    _isWakeWordListening = true;
    debugPrint('[WAKE WORD] Starting passive wake word listener loop...');

    await AuraSTTService.instance.startListening(
      onResult: (text, isFinal) {
        final lowerText = text.toLowerCase();
        debugPrint('[WAKE WORD] Passive heard: "$lowerText"');
        if (_isProcessing) {
          debugPrint('[WAKE WORD] Ignoring — LLM is actively processing.');
          return;
        }
        if (lowerText.contains('hey aura') ||
            lowerText.contains('hey ora') ||
            lowerText.contains('aura')) {
          debugPrint('[WAKE WORD] Wake word detected!');
          _isWakeWordListening = false;
          _wakeWordRestartTimer?.cancel();
          _wakeWordRestartTimer = null;
          Future(() async {
            await AuraSTTService.instance.stopListening();
            await Future.delayed(const Duration(milliseconds: 300));
            await handleMicTap(userInitiated: false);
          });
        }
      },
      onError: () {
        debugPrint('[WAKE WORD] Passive STT error occurred.');
        _isWakeWordListening = false;
        _scheduleNextWakeWordCycle();
      },
    );

    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = Timer(const Duration(seconds: 32), () async {
      debugPrint('[WAKE WORD] Passive listening timeout — cycling STT...');
      _isWakeWordListening = false;
      await AuraSTTService.instance.stopListening();
      _runWakeWordCycle();
    });
  }

  void _scheduleNextWakeWordCycle() {
    _wakeWordRestartTimer?.cancel();
    _wakeWordRestartTimer = Timer(
      const Duration(seconds: 2),
      _runWakeWordCycle,
    );
  }

  void _resumeWakeWordIfEnabled() {
    if (_wakeWordEnabled) {
      _isWakeWordListening = false;
      _runWakeWordCycle();
    }
  }
}
