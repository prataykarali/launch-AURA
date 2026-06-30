part of 'service.dart';

extension _ProactiveSchedulerTriggers on ProactiveScheduler {
  Future<void> _checkTriggers() async {
    if (_shouldDeferProactive()) return;

    final now = DateTime.now();

    // Check cooldown
    if (_lastActivation != null &&
        now.difference(_lastActivation!) < ProactiveScheduler.cooldownDuration) {
      return;
    }

    // 1. Time-based triggers
    final hour = now.hour;
    if (hour == 8 && !_triggeredHours.contains(8)) {
      _triggeredHours.add(8);
      await _triggerProactive(
        _wrapTrigger(ProactiveScheduler._kMorningId, "morning_greeting", "clock"),
      );
      return;
    }
    if (hour == 14 && !_triggeredHours.contains(14)) {
      _triggeredHours.add(14);
      await _triggerProactive(
        _wrapTrigger(ProactiveScheduler._kAfternoonId, "afternoon_checkin", "clock"),
      );
      return;
    }
    if (hour == 20 && !_triggeredHours.contains(20)) {
      _triggeredHours.add(20);
      await _triggerProactive(
        _wrapTrigger(ProactiveScheduler._kEveningId, "evening_winddown", "clock"),
      );
      return;
    }

    // Clear triggered hours at midnight
    if (hour == 0) {
      _triggeredHours.clear();
    }

    // 2. Idle-uptime trigger: if the user has been silent for idleThreshold
    //    (10 min), fire an idle_checkin. Guarded by its own cooldown to avoid
    //    back-to-back idle pings. This is distinct from the clock-hour triggers
    //    above — it's time-elapsed-since-last-interaction based.
    final idle = now.difference(AuraBarBrain.instance.lastUserInteraction);
    if (idle >= ProactiveScheduler.idleThreshold) {
      // Don't re-trigger if we already fired an idle ping recently.
      if (_lastIdleTrigger == null ||
          now.difference(_lastIdleTrigger!) >= ProactiveScheduler.cooldownDuration) {
        debugPrint(
          'AuraProactiveScheduler: idle uptime trigger (${idle.inMinutes} min since last interaction)',
        );
        _lastIdleTrigger = now;
        await _triggerProactive(_wrapTrigger(ProactiveScheduler._kIdleId, "idle_checkin", "idle"));
        return;
      }
    }

    // 3. LLM-driven triggers via Rust check
    try {
      final label = await auraCheckProactive();
      if (label.isNotEmpty) {
        debugPrint(
          'AuraProactiveScheduler: rust proactive trigger detected: $label',
        );
        await _triggerProactive(label);
      }
    } catch (e) {
      debugPrint('AuraProactiveScheduler: rust check error: $e');
    }
  }

  Future<void> _triggerProactive(String triggerType) async {
    if (_shouldDeferProactive()) return;
    if (!_passesCategoryWeight(triggerType)) return;
    _lastActivation = DateTime.now();
    debugPrint(
      'AuraProactiveScheduler: triggering proactive event: $triggerType',
    );

    // Delegate the actual LLM generation, UI presentation and TTS speaking to AuraBarBrain
    await AuraBarBrain.instance.handleProactiveTrigger(triggerType);
  }

  bool _passesCategoryWeight(String triggerType) {
    String category = 'bandit';
    try {
      if (triggerType.startsWith('{')) {
        final decoded = jsonDecode(triggerType);
        if (decoded is Map<String, dynamic>) {
          category = decoded['type']?.toString() ?? category;
        }
      }
    } catch (_) {}
    final weight = _categoryWeights[category] ?? 1.0;
    if (weight >= 1.0) return true;
    final passed = _rng.nextDouble() <= weight;
    if (!passed) {
      debugPrint(
        'AuraProactiveScheduler: skipped $category by learned weight '
        '${weight.toStringAsFixed(2)}',
      );
    }
    return passed;
  }

  bool _shouldDeferProactive() {
    final brain = AuraBarBrain.instance;
    if (brain.userIsTyping ||
        brain.isProcessing ||
        AuraTTSService.instance.isPlaying ||
        ResourceGuardService.instance.isThrottled) {
      debugPrint('AuraProactiveScheduler: deferred — AURA is busy');
      return true;
    }
    return false;
  }
}
