part of 'bar_brain.dart';

extension AuraBarBrainMic on AuraBarBrain {
  Future<void> handleMicTap({bool userInitiated = true}) async {
    lastUserInteraction = DateTime.now();

    if (!engineReady) {
      _androidInitInProgress = true;
      await showProcessingTransition('Warming up AURA...');
      return;
    }

    if (_isProcessing && !_isProcessingStale) {
      if (userInitiated) {
        await showProcessingTransition('Just a moment...');
      }
      return;
    }

    if (_isProcessingStale) {
      await cancelCurrentOps();
    }

    if (AuraSTTService.instance.isListening) {
      await _stopListeningAndProcess();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    _cleanupListening();
    _wakeWordRestartTimer?.cancel();

    _currentResponse = '';
    _sentenceBuffer = '';
    _isProactive = false;
    _clearProactiveTrigger();

    final ok = await AuraSTTService.instance.init();
    if (!ok) {
      await _updateBar(BarState.idle, message: 'Voice input unavailable.');
      return;
    }

    await _updateBar(BarState.listening, message: 'Listening...');
    _lastBarPush = DateTime.fromMillisecondsSinceEpoch(0);

    _silenceSub = AuraSTTService.instance.soundLevelStream.listen((level) {
      if (level < 0.03) return;
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
        unawaited(_stopListeningAndProcess());
      });
    });

    _maxListenTimer = Timer(const Duration(seconds: 10), () {
      unawaited(_stopListeningAndProcess());
    });

    try {
      await AuraSTTService.instance.startListening(
        onResult: (text, isFinal) {
          _partialTranscriptTimer?.cancel();
          _partialTranscriptTimer = Timer(const Duration(milliseconds: 1200), () {
            if (text.trim().isNotEmpty) {
              unawaited(_stopListeningAndProcess(finalText: text));
            }
          });

          if (text.trim().isNotEmpty) {
            _streamUpdate(BarState.listening, text);
          }

          if (isFinal && text.trim().isNotEmpty) {
            _partialTranscriptTimer?.cancel();
            unawaited(_stopListeningAndProcess(finalText: text));
          }
        },
        onError: () {
          _cleanupListening();
          _updateBar(BarState.idle, message: 'Could not hear you.');
          _resumeWakeWordIfEnabled();
        },
      );
    } catch (e) {
      debugPrint('AuraBarBrain: startListening error: $e');
      _cleanupListening();
      _updateBar(BarState.idle, message: 'Mic unavailable.');
    }
  }

  Future<void> _stopListeningAndProcess({String? finalText}) async {
    _cleanupListening();

    var transcript = finalText ?? '';
    if (transcript.isEmpty) {
      transcript = await AuraSTTService.instance.finalizeListening();
    } else {
      await AuraSTTService.instance.stopListening();
    }

    final text = transcript.trim();
    if (text.isNotEmpty) {
      await processUserPrompt(text, source: AuraObservationSource.speech);
    } else {
      await _updateBar(BarState.idle);
      _resumeWakeWordIfEnabled();
    }
  }

  void _cleanupListening() {
    _maxListenTimer?.cancel();
    _silenceTimer?.cancel();
    _partialTranscriptTimer?.cancel();
    _silenceSub?.cancel();
    _silenceSub = null;
    _maxListenTimer = null;
    _silenceTimer = null;
    _partialTranscriptTimer = null;
  }
}
