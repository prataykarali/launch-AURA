part of 'service.dart';

extension ProactiveSchedulerTriggers on ProactiveScheduler {
  /// Public method to force an immediate schedule-note check.
  /// Called after the user sends a schedule-related prompt (e.g. "remind me
  /// to drink water in 2 minutes") so the timer is created immediately
  /// instead of waiting for the next 15-30 min scheduler cycle.
  /// Bypasses the _checkTriggers cooldown guard since this is user-initiated.
  ///
  /// FIX: Added 2-second delay before checking because the Rust engine stores
  /// schedule notes asynchronously. Without this delay, _checkScheduleNotes
  /// runs before the note exists in the database and finds nothing.
  /// Also retries up to 3 times if the note isn't found on first check.
  Future<void> forceScheduleCheck() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future.delayed(Duration(seconds: attempt == 0 ? 2 : 3));
      final before = _scheduleTimers.length;
      await _checkScheduleNotes(DateTime.now());
      if (_scheduleTimers.length > before) {
        debugPrint(
          'AuraProactiveScheduler: forceScheduleCheck succeeded on attempt ${attempt + 1}',
        );
        return; // Timer was created — done.
      }
      debugPrint(
        'AuraProactiveScheduler: forceScheduleCheck attempt ${attempt + 1} found no new notes',
      );
    }
    debugPrint(
      'AuraProactiveScheduler: forceScheduleCheck exhausted retries — note may not be stored yet',
    );
  }

  Future<void> _checkTriggers() async {
    final now = DateTime.now();

    // 0) User-initiated schedule reminders always win and ignore global cooldown.
    await _checkScheduleNotes(now);

    // Automated companion nudges (idle + bandit) share a long cooldown.
    if (_lastActivation != null &&
        now.difference(_lastActivation!) <
            ProactiveScheduler.cooldownDuration) {
      debugPrint(
        'AuraProactiveScheduler: automated proactive in cooldown '
        '(${ProactiveScheduler.cooldownDuration.inMinutes}m)',
      );
      return;
    }

    if (_shouldDeferProactive()) return;

    // 1) Idle check-in after sustained silence (quiet companion, not a clock).
    if (await _maybeIdleTrigger(now)) return;

    // 2) Bandit RL suggestion from Rust (ε-greedy + engagement learning).
    await _maybeBanditTrigger(now);
  }

  /// Fire `idle_checkin` when the user has been silent long enough.
  /// Returns true if a trigger was dispatched (caller should skip bandit).
  Future<bool> _maybeIdleTrigger(DateTime now) async {
    final silence = now.difference(AuraBarBrain.instance.lastUserInteraction);
    if (silence < ProactiveScheduler.idleThreshold) return false;

    if (_lastIdleTrigger != null &&
        now.difference(_lastIdleTrigger!) < ProactiveScheduler._idleRefireGap) {
      return false;
    }

    final payload = _wrapTrigger(
      ProactiveScheduler._kIdleId,
      'idle_checkin',
      'idle',
    );
    debugPrint(
      'AuraProactiveScheduler: idle_checkin '
      '(silent ${silence.inMinutes}m ≥ ${ProactiveScheduler.idleThreshold.inMinutes}m)',
    );
    final before = _lastActivation;
    await _triggerProactive(payload);
    // Only consume the idle slot if the trigger actually dispatched.
    if (_lastActivation != before) {
      _lastIdleTrigger = now;
      return true;
    }
    return false;
  }

  /// Ask Rust bandit for a trigger arm; fire if one is eligible.
  Future<void> _maybeBanditTrigger(DateTime now) async {
    // Soft throttle so we don't hammer FFI every poll when nothing is eligible.
    if (_lastBanditAttempt != null &&
        now.difference(_lastBanditAttempt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastBanditAttempt = now;

    try {
      final suggestion = await auraCheckProactive();
      if (suggestion.trim().isEmpty) {
        debugPrint('AuraProactiveScheduler: bandit returned no suggestion');
        return;
      }
      debugPrint('AuraProactiveScheduler: bandit suggestion → $suggestion');
      await _triggerProactive(suggestion);
    } catch (e) {
      debugPrint('AuraProactiveScheduler: bandit check error: $e');
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
        final content = trimmed.startsWith('- ')
            ? trimmed.substring(2)
            : trimmed;
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
    final inMatch = RegExp(
      r'in (?:an? )?(\d+) (minutes?|mins?|hours?|hrs?|secs?|seconds?)',
    ).firstMatch(lower);
    if (inMatch != null) {
      final n = int.parse(inMatch.group(1)!);
      final unit = inMatch.group(2)!;
      if (unit.startsWith('min')) return Duration(minutes: n);
      if (unit.startsWith('hour') || unit.startsWith('hr'))
        return Duration(hours: n);
      if (unit.startsWith('sec')) return Duration(seconds: n);
    }
    // Handle "in an hour" / "in a minute" without a number.
    if (RegExp(r'in an? hour').hasMatch(lower)) return const Duration(hours: 1);
    if (RegExp(r'in a minute').hasMatch(lower))
      return const Duration(minutes: 1);

    // "at N AM" / "at N PM" / "at N:MM AM" / "at N PM"
    final atMatch = RegExp(
      r'at (\d{1,2})(?::(\d{2}))?\s*(am|pm)',
    ).firstMatch(lower);
    if (atMatch != null) {
      var hour = int.parse(atMatch.group(1)!);
      final minute = int.parse(atMatch.group(2) ?? '0');
      final ampm = atMatch.group(3)!;
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      var fireTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (fireTime.isBefore(now))
        fireTime = fireTime.add(const Duration(days: 1));
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
      if (fireTime.isBefore(now))
        fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "noon" → 12:00 PM today (or tomorrow if past noon).
    if (lower.contains('noon')) {
      var fireTime = DateTime(now.year, now.month, now.day, 12, 0);
      if (fireTime.isBefore(now))
        fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "midnight" → 00:00 tomorrow.
    if (lower.contains('midnight')) {
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      return tomorrow.difference(now);
    }

    // "tonight" → 9 PM today (or tomorrow if past 9 PM).
    if (lower.contains('tonight')) {
      var fireTime = DateTime(now.year, now.month, now.day, 21, 0);
      if (fireTime.isBefore(now))
        fireTime = fireTime.add(const Duration(days: 1));
      return fireTime.difference(now);
    }

    // "tomorrow morning" → 9 AM tomorrow.
    if (lower.contains('tomorrow morning')) {
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        9,
        0,
      ).difference(now);
    }

    // "tomorrow" without specific time → 9 AM tomorrow (not 8h from now).
    if (lower.contains('tomorrow') && !lower.contains('at ')) {
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        9,
        0,
      ).difference(now);
    }

    return null;
  }

  /// Extract the human-readable reminder text from a schedule note.
  String _extractReminderText(String content) {
    var text = content.replaceAll('Schedule request: ', '').trim();
    text = text.replaceAll(
      RegExp(
        r"^(remind me to|don't let me forget to|dont let me forget to|set a reminder to|wake me up at|schedule)\s+",
      ),
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
    if (brain.userIsTyping || brain.isProcessing) {
      debugPrint('AuraProactiveScheduler: deferred — AURA is busy');
      return true;
    }
    // Allow proactive even if TTS is playing — the generation will queue
    // behind the current speech. Only defer if TTS just started (< 2s ago)
    // to avoid interrupting the beginning of a response.
    if (AuraTTSService.instance.isPlaying &&
        brain.lastUserInteraction.difference(DateTime.now()).abs() <
            const Duration(seconds: 2)) {
      debugPrint('AuraProactiveScheduler: deferred — user just spoke');
      return true;
    }
    if (ResourceGuardService.instance.isThrottled) {
      debugPrint('AuraProactiveScheduler: deferred — resource throttled');
      return true;
    }
    return false;
  }
}
