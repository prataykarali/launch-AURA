part of 'bar_brain.dart';

extension AuraBarBrainGreeting on AuraBarBrain {
  Future<void> _answerPlainGreeting() async {
    if (_isProcessing) return;

    // Anti-spam: enforce a cooldown between plain greetings so a single wave
    // (or a run of noisy vision detections) does not trigger a burst of
    // "Hello!" TTS utterances.
    final now = DateTime.now();
    if (_lastGestureGreetingAt != null &&
        now.difference(_lastGestureGreetingAt!) < const Duration(seconds: 12)) {
      return;
    }
    _lastGestureGreetingAt = now;

    _isProactive = true;
    _clearProactiveTrigger();
    _currentTriggerId = -30;
    _currentTriggerLabel = 'gesture_greeting';
    _currentTriggerType = 'vision';
    _currentTriggerData = const {'event': 'gesture'};
    _currentResponse = '';
    _sentenceBuffer = '';

    const greetings = [
      'Hey there! 👋',
      'Hello! Nice to see you.',
      'Hi! How can I help?',
      'Hey! Ready when you are.',
    ];
    final greeting = greetings[DateTime.now().second % greetings.length];

    _currentResponse = greeting;
    await _updateBar(BarState.proactive, message: greeting);

    if (_ttsEnabled && !isMuted) {
      unawaited(AuraTTSService.instance.speak(greeting));
    }

    _responseFadeTimer?.cancel();
    _responseFadeTimer = Timer(const Duration(seconds: 5), () {
      _updateBar(BarState.idle);
      _resumeWakeWordIfEnabled();
    });
  }
}
