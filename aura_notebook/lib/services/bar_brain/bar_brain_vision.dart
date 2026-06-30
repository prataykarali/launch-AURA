part of 'bar_brain.dart';

extension AuraBarBrainVision on AuraBarBrain {
  // Called by VisionService each time a detection batch is sent to Rust.
  // Gesture fast-path: if the camera/vision pipeline surfaces a wave or
  // greeting gesture, respond immediately with a natural AURA greeting.
  // All other detections are forwarded to NaturalContextService as before.
  static const _kGestureKeywords = [
    'wave', 'waving', 'hand_wave', 'greeting',
    'open_palm', 'thumbs_up', 'hi_gesture',
    'hands_raised', 'hand gesture', 'hand pose',
    'raised', 'palm',
  ];

  void _onVisionDetected(List<String> labels, double confidence) {
    // Check for wave / greeting gesture using substring matching
    // (vision pipeline labels like "user waving / hand gesture" or
    // "open_palm_or_wave_pose" won't exact-match a fixed set).
    final hasGesture = labels.any((l) {
      final lower = l.toLowerCase();
      return _kGestureKeywords.any((kw) => lower.contains(kw));
    });
    if (hasGesture && confidence >= 0.35 && !_isProcessing) {
      debugPrint(
        '[AURA Vision] Gesture detected (labels=$labels conf=$confidence) — greeting',
      );
      unawaited(_answerPlainGreeting());
      return;
    }

    unawaited(
      NaturalContextService.instance.observeVision(
        labels: labels,
        confidence: confidence,
      ),
    );
  }

  void _onVisionContext(AuraVisionContext context) {
    unawaited(
      NaturalContextService.instance.observeVisionContext(context.toJson()),
    );
    if (context.stuck && VisionService.instance.consumeStuckEpisodeTrigger()) {
      final payload = jsonEncode({
        'id': -30,
        'label': 'stuck_screen',
        'type': 'vision',
        'event': context.toJson(),
      });
      unawaited(handleProactiveTrigger(payload));
    }
  }

  Future<void> handleResourcePressure(ResourcePressureEvent event) async {
    final now = DateTime.now();
    if (_lastHealthWarningAt != null &&
        now.difference(_lastHealthWarningAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastHealthWarningAt = now;

    debugPrint(
      '[AURA_HEALTH] critical pressure (${event.reason}): '
      '${event.snapshot.debugLabel}',
    );

    try {
      auraCancel();
    } catch (e) {
      debugPrint('[AURA_HEALTH] auraCancel failed before engine ready: $e');
    }
    await _chatSubscription?.cancel();
    _chatSubscription = null;
    _stopThinkingAnimation();
    _maxListenTimer?.cancel();
    _maxListenTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _partialTranscriptTimer?.cancel();
    _partialTranscriptTimer = null;
    await _silenceSub?.cancel();
    _silenceSub = null;
    _responseFadeTimer?.cancel();
    _responseFadeTimer = null;

    await AuraSTTService.instance.cancelListening();
    await AuraTTSService.instance.stop();
    VisionService.instance.pauseForHealth(event.cooldown);
    ResourceGuardService.instance.pauseNonEssentialWork(event.cooldown);

    _isProcessing = false;
    _isProactive = false;
    _processingStartedAt = null;
    _clearProactiveTrigger();
    final lock = _processingLock;
    _processingLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    final message = event.appDominant
        ? 'AURA paused itself to stay safe. Close a heavy app, then try again.'
        : 'Your laptop memory is almost full. I paused extra senses; close something heavy.';

    await AuraBarMultiWindowService.instance.showOrCreateBar(
      state: BarState.warning,
      proactiveMessage: message,
      muted: isMuted,
    );
    await _updateBar(BarState.warning, message: message);
    _healthWarningTimer?.cancel();
    _healthWarningTimer = Timer(event.cooldown, () {
      if (_state == BarState.warning &&
          !ResourceGuardService.instance.isThrottled) {
        _updateBar(BarState.idle);
        _resumeWakeWordIfEnabled();
      }
    });
  }

  Future<void> _showHealthPauseWarning() async {
    const message =
        'AURA is cooling down to stay stable. Close something heavy, then try again.';
    await AuraBarMultiWindowService.instance.showOrCreateBar(
      state: BarState.warning,
      proactiveMessage: message,
      muted: isMuted,
    );
    await _updateBar(BarState.warning, message: message);
    _healthWarningTimer?.cancel();
    _healthWarningTimer = Timer(const Duration(seconds: 8), () {
      if (_state == BarState.warning &&
          !ResourceGuardService.instance.isThrottled) {
        _updateBar(BarState.idle);
        _resumeWakeWordIfEnabled();
      }
    });
  }
}
