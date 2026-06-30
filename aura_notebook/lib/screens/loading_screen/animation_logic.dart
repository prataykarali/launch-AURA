part of 'main.dart';

extension _LoadingScreenAnimationLogic on _LoadingScreenState {
  void _startWarmupCreep() {
    _creepTimer?.cancel();
    _creeping = true;
    _creepValue = 0.90;
    _creepTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_creeping) return;
      // Ease toward 0.99 — slower as it approaches, never overshooting.
      final remaining = 0.99 - _creepValue;
      if (remaining <= 0.001) return;
      _creepValue += remaining * 0.06;
      _updateState(() {});
    });
  }

  void _stopWarmupCreep() {
    _creeping = false;
    _creepTimer?.cancel();
    _creepTimer = null;
  }

  Future<void> _cycleQuote() async {
    if (_errorMsg != null) return;
    HapticFeedback.selectionClick();
    await _quoteCtrl.reverse();
    if (!mounted) return;
    _updateState(() {
      _quoteIndex++;
      if (_quoteIndex >= _shuffledQuotes.length) {
        _shuffledQuotes.shuffle(_random);
        _quoteIndex = 0;
      }
    });
    await _quoteCtrl.forward();
  }
}
