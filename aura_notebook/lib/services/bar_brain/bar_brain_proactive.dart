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
    if (_proactiveLock || _isProcessing || userIsTyping || AuraTTSService.instance.isPlaying) {
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

    // For clock-based greetings, use a clean template WITHOUT conversation
    // context to prevent prior topics from contaminating the greeting.
    if (type == 'clock' || label == 'morning_greeting' ||
        label == 'afternoon_checkin' || label == 'evening_winddown') {
      final greeting = switch (label) {
        'morning_greeting' => 'Good morning',
        'afternoon_checkin' => 'Good afternoon',
        'evening_winddown' => 'Good evening',
        _ => 'Hello',
      };
      buffer.writeln('Say a brief, warm $greeting to the user.');
      buffer.writeln('Reply in 1-2 sentences. Be natural and friendly.');
      buffer.writeln('Do NOT mention any previous conversations or context.');
      return buffer.toString().trim();
    }

    // For non-greeting triggers, include context but keep it compact.
    buffer.writeln('AURA is being proactive. Context:');
    buffer.writeln('  trigger_label=$label');
    buffer.writeln('  trigger_type=$type');

    final event = data['event'];
    if (event is Map) {
      final summary = event['summary']?.toString();
      if (summary != null && summary.isNotEmpty) {
        buffer.writeln('  observed=$summary');
      }
    }

    final sustainedSummary = data['sustained_summary']?.toString();
    if (sustainedSummary != null && sustainedSummary.isNotEmpty) {
      buffer.writeln('  guidance=$sustainedSummary');
    }

    // Only include memory context for non-greeting triggers, and limit it
    // to avoid flooding the prompt with irrelevant prior conversation.
    try {
      final context = await auraGetProactiveContext();
      if (context.isNotEmpty) {
        // Limit memory context to 200 chars to prevent contamination.
        final limited = context.length > 200
            ? '${context.substring(0, 200)}...'
            : context;
        buffer.writeln('  memory_context=$limited');
      }
    } catch (e) {
      debugPrint('AuraBarBrain: proactive context fetch failed: $e');
    }

    buffer.writeln(
      'Reply with a very brief, natural English message. If the context does not justify interrupting the user, reply exactly SILENT (no punctuation).',
    );
    return buffer.toString().trim();
  }
}
