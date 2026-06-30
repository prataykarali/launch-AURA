part of 'bar_brain.dart';

extension AuraBarBrainVolume on AuraBarBrain {
  double get volume => AuraTTSService.instance.volume;
  bool get isMuted => AuraTTSService.instance.isMuted;

  void setVolume(double v) {
    AuraTTSService.instance.setVolume(v);
    volumeNotifier.value = AuraTTSService.instance.volume;
    unawaited(pushMuteState());
  }

  void toggleVolume() {
    AuraTTSService.instance.toggleMute();
    volumeNotifier.value = AuraTTSService.instance.volume;
    final nowMuted = AuraTTSService.instance.isMuted;
    if (ttsEnabledNotifier.value == nowMuted) {
      ttsEnabledNotifier.value = !nowMuted;
    }
    unawaited(pushMuteState());
  }

  void volumeDown() {
    final next = (AuraTTSService.instance.volume - 0.2).clamp(0.0, 1.0);
    AuraTTSService.instance.setVolume(next);
    volumeNotifier.value = next;
    unawaited(pushMuteState());
  }

  void volumeUp() {
    final next = (AuraTTSService.instance.volume + 0.2).clamp(0.0, 1.0);
    AuraTTSService.instance.setVolume(next);
    volumeNotifier.value = next;
    unawaited(pushMuteState());
  }

  bool get ttsEnabled => _ttsEnabled;

  void toggleTts() {
    _ttsEnabled = !_ttsEnabled;
    ttsEnabledNotifier.value = _ttsEnabled;
    if (!_ttsEnabled) unawaited(AuraTTSService.instance.stop());
    debugPrint('[AURA] TTS ${_ttsEnabled ? "enabled" : "disabled"}');
  }
}
