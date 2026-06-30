part of 'bar_brain.dart';

extension AuraBarBrainPublic on AuraBarBrain {
  // ── Cancel / reset ─────────────────────────────────────────────────────────
  Future<void> cancelCurrentOps() async {
    debugPrint('AuraBarBrain: cancelling current operations');

    _maxListenTimer?.cancel();
    _silenceTimer?.cancel();
    _partialTranscriptTimer?.cancel();
    await _silenceSub?.cancel();
    _silenceSub = null;

    _wakeWordRestartTimer?.cancel();
    _responseFadeTimer?.cancel();
    _barFlushTimer?.cancel();
    _thinkingTimer?.cancel();
    _proactiveTimeout?.cancel();
    _healthWarningTimer?.cancel();

    await _chatSubscription?.cancel();
    _chatSubscription = null;

    await AuraSTTService.instance.cancelListening();
    await AuraTTSService.instance.stop();

    try {
      auraCancel();
    } catch (e) {
      debugPrint('AuraBarBrain: auraCancel failed during cancel: $e');
    }

    _isProcessing = false;
    _processingStartedAt = null;
    _isProactive = false;
    _currentResponse = '';
    _sentenceBuffer = '';
    _clearProactiveTrigger();

    final lock = _processingLock;
    _processingLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    await _updateBar(BarState.idle);
    _resumeWakeWordIfEnabled();
  }

  // ── Replay current response via TTS ────────────────────────────────────────
  Future<void> speakResponse(String response) async {
    final text = response.trim();
    if (text.isEmpty || !_ttsEnabled || isMuted) return;
    await _updateBar(BarState.speaking, message: _visibleBarBeats(text));
    unawaited(AuraTTSService.instance.speak(text));
  }

  // ── Model loading progress surfaced in the bar ─────────────────────────────
  void showModelLoadingStatus(String step) {
    final message = 'Loading ${step.replaceAll('_', ' ')}...';
    unawaited(_updateBar(BarState.processing, message: message));
  }

  /// Clear any loading overlay from the AURA bar and return it to idle.
  void clearLoadingOverlay() {
    unawaited(_updateBar(BarState.idle));
  }
}
