part of 'bar_brain.dart';

extension AuraBarBrainEngine on AuraBarBrain {
  void setEngineReady() {
    if (engineReady) return;
    engineReady = true;
    _androidInitInProgress = false;
    _flushPending();
    if (Platform.isLinux) {
      unawaited(SttModelService.instance.ensureDownloaded());
    }
    // Camera and proactive settings — disabled by env vars AURA_CAMERA_OFF
    // and AURA_PROACTIVE_OFF to prevent camera/YOLO spam.
    final cameraOff = Platform.environment['AURA_CAMERA_OFF'] == '1';
    final proactiveOff = Platform.environment['AURA_PROACTIVE_OFF'] == '1';

    if (!proactiveOff) {
      NaturalContextService.instance.onNaturalTrigger = handleProactiveTrigger;
    }
    if (!cameraOff) {
      VisionService.instance.onDetectionSent = _onVisionDetected;
      VisionService.instance.onStructuredContext = _onVisionContext;
    }
    VisionService.instance.start();
    debugPrint(
      '[AURA] Passive sensing started (camera=${cameraOff ? "OFF" : "on"}, proactive=${proactiveOff ? "OFF" : "on"})',
    );
  }

  void onBarVisible() {
    if (Platform.isLinux &&
        _gestureWatchTimer == null &&
        Platform.environment['AURA_CAMERA_OFF'] != '1') {
      debugPrint('[AURA] Bar visible — starting gesture watch');
      _startGestureWatch();
    }
  }

  void onBarHidden() {
    if (Platform.isLinux && _gestureWatchTimer != null) {
      debugPrint('[AURA] Bar hidden — stopping gesture watch');
      _gestureWatchTimer?.cancel();
      _gestureWatchTimer = null;
    }
  }

  void _startGestureWatch() {
    _gestureWatchTimer?.cancel();
    // Show "AURA is watching" bar animation instead of camera window
    _updateBar(BarState.watching, message: 'AURA is watching...');
    _gestureWatchTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollWebcamGesture(),
    );
    // Kick one immediately so the camera warms up without a 10s delay.
    unawaited(_pollWebcamGesture());
  }

  Future<void> _pollWebcamGesture() async {
    if (_isProcessing || _state == BarState.listening || _state == BarState.processing) {
      return;
    }
    try {
      final gesture = await auraGetWebcamGesture();
      if (gesture.isEmpty) return;
      // Cooldown so a single wave is one greeting, not a burst.
      final now = DateTime.now();
      if (_lastGestureGreetingAt != null &&
          now.difference(_lastGestureGreetingAt!) < const Duration(seconds: 12)) {
        return;
      }
      _lastGestureGreetingAt = now;
      debugPrint('[AURA Vision] Webcam gesture polled ($gesture) — greeting');
      unawaited(_answerPlainGreeting());
    } catch (e) {
      // Camera unavailable / permission missing — stay quiet, retry next tick.
      debugPrint('[AURA Vision] gesture poll error: $e');
    }
  }

  void _flushPending() {
    if (_promptQueue.isEmpty) return;
    final queued = _promptQueue.removeAt(0);
    debugPrint('AuraBarBrain: engine ready — flushing queued prompt: "${queued.text}"');
    unawaited(processUserPrompt(queued.text, source: queued.source));
  }

  // ── _releaseProcessingLock ────────────────────────────────────────────────
  void _releaseProcessingLock() {
    _isProcessing = false;
    _processingStartedAt = null;
    final lock = _processingLock;
    _processingLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    // Replay the next queued prompt (if any). FIFO order.
    if (_promptQueue.isNotEmpty) {
      final queued = _promptQueue.removeAt(0);
      debugPrint('AuraBarBrain: replaying queued prompt: "${queued.text}"');
      Future.microtask(() => processUserPrompt(queued.text, source: queued.source));
    }
  }
}
