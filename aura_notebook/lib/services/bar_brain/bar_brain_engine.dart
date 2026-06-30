part of 'bar_brain.dart';

extension AuraBarBrainEngine on AuraBarBrain {
  void setEngineReady() {
    if (engineReady) return;
    engineReady = true;
    _androidInitInProgress = false;
    _flushPending();
    // Background-fetch the STT model so the mic path can use sherpa instead
    // of being unavailable. Only on Linux where sherpa-onnx voice feature is enabled.
    // Android uses platform speech_to_text (no sherpa model needed).
    if (Platform.isLinux) {
      unawaited(SttModelService.instance.ensureDownloaded());
    }
    // Keep passive context sensing free and privacy-preserving: screen title
    // context may run in the background, but the webcam is opened only from an
    // explicit watch/vision prompt on the Rust side.
    NaturalContextService.instance.onNaturalTrigger = handleProactiveTrigger;
    VisionService.instance.onDetectionSent = _onVisionDetected;
    VisionService.instance.onStructuredContext = _onVisionContext;
    VisionService.instance.start();
    debugPrint(
      '[AURA] Passive screen/context sensing started; webcam remains off until watch mode',
    );
    // Start the headless webcam gesture watch on Linux so a wave/gesture
    // triggers an immediate AURA greeting. The Rust side runs the camera
    // without a display window; each poll re-extends the watch session.
    if (Platform.isLinux) {
      _startGestureWatch();
    }
  }

  void _startGestureWatch() {
    _gestureWatchTimer?.cancel();
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
    final p = _pendingPrompt;
    if (p == null) return;
    final source = _pendingPromptSource;
    _pendingPrompt = null;
    _pendingPromptSource = AuraObservationSource.text;
    debugPrint('AuraBarBrain: engine ready — flushing pending prompt: "$p"');
    unawaited(processUserPrompt(p, source: source));
  }

  // ── _releaseProcessingLock ────────────────────────────────────────────────
  void _releaseProcessingLock() {
    _isProcessing = false;
    _processingStartedAt = null;
    final lock = _processingLock;
    _processingLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    // Replay the queued prompt (if any). This runs synchronously after the
    // turn's onDone/onError calls release, so the next turn starts immediately
    // without the user re-submitting. Fire-and-forget: it owns its own lock.
    final queued = _pendingPrompt;
    if (queued != null) {
      final source = _pendingPromptSource;
      _pendingPrompt = null;
      _pendingPromptSource = AuraObservationSource.text;
      Future.microtask(() => processUserPrompt(queued, source: source));
    }
  }
}
