part of 'bar_brain.dart';

extension AuraBarBrainUi on AuraBarBrain {
  Future<void> _updateBar(BarState state, {String? message}) async {
    _state = state;
    try {
      await AuraBarMultiWindowService.instance.sendState(
        state,
        proactiveMessage: message,
        muted: isMuted,
      );
    } catch (e) {
      debugPrint('AuraBarBrain: Failed to update bar state: $e');
    }
  }

  /// Public method to show a brief processing state for smooth transitions.
  Future<void> showProcessingTransition(String message) async {
    await _updateBar(BarState.processing, message: message);
  }

  /// Synchronize the bar state from external sources (e.g. background overlay).
  Future<void> syncState(BarState state, {String? message}) async {
    await _updateBar(state, message: message);
  }

  /// Push the current mute state to all bar windows (Android overlay + desktop).
  /// Call this after any volume/mute change to ensure all mirrors stay in sync.
  Future<void> pushMuteState() async {
    try {
      await AuraBarMultiWindowService.instance.sendState(
        currentState,
        muted: isMuted,
      );
    } catch (e) {
      debugPrint('AuraBarBrain: Failed to push mute state: $e');
    }
  }

  /// Throttled bar push: coalesces rapid token updates into ≤12 IPC/sec.
  void _streamUpdate(BarState state, String message) {
    _pendingBarState = state;

    // On Android the pill is a very small overlay — keep messages shorter
    // to prevent text overflow and typewriter glitches.
    final maxLen = Platform.isAndroid
        ? (state == BarState.proactive ? 70 : 80)
        : (state == BarState.proactive ? 100 : 140);
    _pendingBarMessage = message.length > maxLen
        ? '…${message.substring(message.length - maxLen)}'
        : message;

    final now = DateTime.now();
    final isSentenceEnd =
        !Platform.isAndroid &&
        (message.endsWith('.') ||
            message.endsWith('!') ||
            message.endsWith('?') ||
            message.endsWith('\n'));
    final due = now.difference(_lastBarPush) >= AuraBarBrain._barThrottle;
    if (due || isSentenceEnd) {
      _lastBarPush = now;
      _barFlushTimer?.cancel();
      _barFlushTimer = null;
      _updateBar(state, message: _pendingBarMessage);
    } else {
      _barFlushTimer?.cancel();
      _barFlushTimer = Timer(AuraBarBrain._barThrottle, () {
        _lastBarPush = DateTime.now();
        _updateBar(_pendingBarState, message: _pendingBarMessage);
      });
    }
  }

  // ── Thinking animation ────────────────────────────────────────────────────
  void _startThinkingAnimation() {
    _thinkingTimer?.cancel();
    _updateBar(BarState.processing, message: '...');
  }

  void _stopThinkingAnimation() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
  }
}
