part of 'bar_brain.dart';

extension AuraBarBrainProactive on AuraBarBrain {
  // Lock to prevent TOCTOU race between checking isProcessing/isPlaying
  // and actually starting the proactive generation.
  static bool _proactiveLock = false;

  Future<void> handleProactiveTrigger(String? payload) async {
    lastUserInteraction = DateTime.now();

    if (payload == null || payload.trim().isEmpty) return;
    if (!engineReady) {
      debugPrint('AuraBarBrain: proactive trigger ignored — engine not ready');
      return;
    }
    // Use a lock to prevent race conditions where TTS starts between
    // the check and the generation start.
    if (_proactiveLock ||
        _isProcessing ||
        userIsTyping ||
        AuraTTSService.instance.isPlaying) {
      debugPrint('AuraBarBrain: proactive trigger deferred — busy');
      return;
    }
    _proactiveLock = true;

    final data = _parseTriggerPayload(payload);
    if (data == null) return;

    final id = _parseInt(data['id']);
    final label = data['label']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'bandit';
    final event = data['event'];

    if (label.isEmpty) return;

    _isProcessing = true;
    _processingStartedAt = DateTime.now();
    _processingLock = Completer<void>();
    _isProactive = true;
    _clearProactiveTrigger();
    _currentTriggerId = id;
    _currentTriggerLabel = label;
    _currentTriggerType = type;
    _currentTriggerData = event is Map<String, dynamic>
        ? event
        : <String, dynamic>{};
    _currentResponse = '';
    _sentenceBuffer = '';

    // Start the bandit RL engagement window. If the user responds within
    // 30s, _recordEngagement(true) is called from processUserPrompt.
    // If they don't, the timer fires _recordEngagement(false).
    if (id != null && id > 0) {
      _startEngagementWindow(id, type);
    }

    _startThinkingAnimation();

    try {
      final prompt = await _buildProactivePrompt(label, type, data);
      await _runGeneration(prompt, proactive: true);
    } catch (e, st) {
      debugPrint('AuraBarBrain: handleProactiveTrigger error: $e\n$st');
      _releaseProcessingLock();
      await _updateBar(BarState.idle);
      _resumeWakeWordIfEnabled();
    } finally {
      _proactiveLock = false;
    }
  }

  Map<String, dynamic>? _parseTriggerPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('AuraBarBrain: failed to parse proactive payload: $e');
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<String> _buildProactivePrompt(
    String label,
    String type,
    Map<String, dynamic> data,
  ) async {
    final buffer = StringBuffer();

    // Clock-based greetings: clean template, no context at all.
    if (type == 'clock' ||
        label == 'morning_greeting' ||
        label == 'afternoon_checkin' ||
        label == 'evening_winddown') {
      final greeting = switch (label) {
        'morning_greeting' => 'Good morning',
        'afternoon_checkin' => 'Good afternoon',
        'evening_winddown' => 'Good evening',
        _ => 'Hello',
      };
      buffer.writeln('Say a brief, warm $greeting to the user.');
      buffer.writeln('Reply in 1-2 sentences. Be natural and friendly.');
      buffer.writeln(
        'Do NOT mention any previous conversations, stored facts, names, birthdays, or context.',
      );
      return buffer.toString().trim();
    }

    // Schedule reminders: include only the reminder text.
    if (label == 'schedule_reminder') {
      final event = data['event'];
      final summary = event is Map ? event['summary']?.toString() : null;
      buffer.writeln('AURA has a reminder for the user.');
      if (summary != null && summary.isNotEmpty) {
        buffer.writeln('  reminder=$summary');
      }
      buffer.writeln(
        'Deliver the reminder naturally and briefly. 1-2 sentences.',
      );
      return buffer.toString().trim();
    }

    // All other triggers (idle, bandit, natural context): conversational only.
    buffer.writeln('AURA is being proactive. Say something brief and warm.');

    // Idle triggers: include what the user was last doing (from vision).
    if (label == 'idle_checkin' || type == 'idle') {
      final idleMins = DateTime.now()
          .difference(AuraBarBrain.instance.lastUserInteraction)
          .inMinutes;
      buffer.writeln('  The user has been idle for $idleMins minutes.');

      // Include recent visual context from the vision store.
      try {
        final proactiveCtx = await auraGetProactiveContext();
        if (proactiveCtx.isNotEmpty) {
          buffer.writeln('  Recent context: $proactiveCtx');
        }
      } catch (_) {}
    }

    // Natural context triggers: include the observed event.
    final event = data['event'];
    if (event is Map) {
      final summary = event['summary']?.toString();
      if (summary != null && summary.isNotEmpty) {
        buffer.writeln('  Observed: $summary');
      }
    }

    // Explicit anti-fact-regurgitation rules.
    buffer.writeln('');
    buffer.writeln('RULES:');
    buffer.writeln('- Speak like a friend casually checking in.');
    buffer.writeln(
      '- Do NOT mention user names, birthdays, preferences, or any stored facts.',
    );
    buffer.writeln(
      '- Do NOT say "I remember" or reference previous conversations.',
    );
    buffer.writeln('- Keep it to 1-2 short sentences.');
    buffer.writeln(
      '- If there is no good reason to interrupt, reply exactly: SILENT',
    );

    return buffer.toString().trim();
  }
}
