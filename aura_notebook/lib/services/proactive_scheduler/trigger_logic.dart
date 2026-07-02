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

    // 0. Schedule note check — fire reminders stored as memory_notes
    await _checkScheduleNotes(now);

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

  /// Check pinned schedule notes and set timers for any that haven't been
  /// scheduled yet. Parses time hints like "in 5 minutes", "at 7 AM",
  /// "at 5 PM" from the stored schedule note content.
  Future<void> _checkScheduleNotes(DateTime now) async {
    try {
      final context = await auraGetProactiveContext();
      if (context.isEmpty) return;

      final lines = context.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        // Remove leading "- " from the fact list format
        final content = trimmed.startsWith('- ') ? trimmed.substring(2) : trimmed;
        if (!content.contains('Schedule request:')) continue;

        final noteKey = content.hashCode.toString();
        if (_firedScheduleNotes.contains(noteKey)) continue;
        if (_scheduleTimers.containsKey(noteKey)) continue;

        // Parse the time hint from the schedule note
        final fireDelay = _parseScheduleTimeHint(content, now);
        if (fireDelay == null) continue;

        final reminderText = _extractReminderText(content);
        debugPrint(
          'AuraProactiveScheduler: schedule timer set for "$reminderText" '
          'in ${fireDelay.inSeconds}s',
        );

        _scheduleTimers[noteKey] = Timer(fireDelay, () {
          _firedScheduleNotes.add(noteKey);
          _scheduleTimers.remove(noteKey);
          final payload = jsonEncode({
            'id': ProactiveScheduler._kScheduleReminderId,
            'label': 'schedule_reminder',
            'type': 'text',
            'event': {'summary': 'Reminder: $reminderText'},
          });
          debugPrint(
            'AuraProactiveScheduler: schedule timer FIRED — "$reminderText"',
          );
          _triggerProactive(payload);
        });
      }
    } catch (e) {
      debugPrint('AuraProactiveScheduler: schedule note check error: $e');
    }
  }

  /// Parse a time hint from a schedule note and return the delay until fire.
  /// Supports: "in N minutes", "in N hours", "at N AM/PM", "at N:MM AM/PM",
  /// "noon", "midnight", "in an hour", "tomorrow morning".
  Duration? _parseScheduleTimeHint(String content, DateTime now) {
    final lower = content.toLowerCase();

    // "in N minutes" / "in N mins" / "in N hours" / "in N secs"
    // Also handles "in an hour", "in a minute"
    final inMatch = RegExp(r'in (?:an? )?(\d+) (minutes?|mins?|hours?|hrs?|secs?|seconds?)').firstMatch(lower);
    if (inMatch != null) {
      final n = int.parse(inMatch.group(1)!);
      final unit = inMatch.group(2)!;
      if (unit.startsWith('min')) return Duration(minutes: n);
      if (unit.startsWith('hour') || unit.startsWith('hr')) return Duration(hours: n);
      if (unit.startsWith('sec')) return Duration(seconds: n);
    }
    // Handle "in an hour" / "in a minute" without a number.
    if (RegExp(r'in an? hour').hasMatch(lower)) return const Duration(hours: 1);
    if (RegExp(r'in a minute').hasMatch(lower)) return const Duration(minutes: 1);

    // "at N AM" / "at N PM" / "at N:MM AM" / "at N PM"
    final atMatch = RegExp(r'at (\d{1,2})(?::(\d{2}))?\s*(am|pm)').firstMatch(lower);
    if (atMatch != null) {
      var hour = int.parse(atMatch.group(1)!);
      final minute = int.parse(atMatch.group(2) ?? '0');
      final ampm = atMatch.group(3)!;
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      var fireTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (fireTime.isBefore(now)) fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "at N:MM" without AM/PM — infer from current time.
    final atTimeMatch = RegExp(r'at (\d{1,2}):(\d{2})').firstMatch(lower);
    if (atTimeMatch != null) {
      var hour = int.parse(atTimeMatch.group(1)!);
      final minute = int.parse(atTimeMatch.group(2)!);
      if (hour >= 1 && hour <= 12) {
        // Ambiguous — assume PM if current time is PM, otherwise AM.
        if (now.hour >= 12 && hour < 12) hour += 12;
      }
      var fireTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (fireTime.isBefore(now)) fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "noon" → 12:00 PM today (or tomorrow if past noon).
    if (lower.contains('noon')) {
      var fireTime = DateTime(now.year, now.month, now.day, 12, 0);
      if (fireTime.isBefore(now)) fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "midnight" → 00:00 tomorrow.
    if (lower.contains('midnight')) {
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      return tomorrow.difference(now);
    }

    // "tonight" → 9 PM today (or tomorrow if past 9 PM).
    if (lower.contains('tonight')) {
      var fireTime = DateTime(now.year, now.month, now.day, 21, 0);
      if (fireTime.isBefore(now)) fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "tomorrow morning" → 9 AM tomorrow.
    if (lower.contains('tomorrow morning')) {
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0).difference(now);
    }

    // "tomorrow" without specific time → 9 AM tomorrow (not 8h from now).
    if (lower.contains('tomorrow') && !lower.contains('at ')) {
      final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0).difference(now);
    }

    return null;
  }

  /// Extract the human-readable reminder text from a schedule note.
  String _extractReminderText(String content) {
    var text = content.replaceAll('Schedule request: ', '').trim();
    text = text.replaceAll(
      RegExp(r"^(remind me to|don't let me forget to|dont let me forget to|set a reminder to|wake me up at|schedule)\s+"),
      '',
    );
    return text.trim();
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
