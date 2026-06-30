part of 'bar_brain.dart';

extension AuraBarBrainProactive on AuraBarBrain {
  Future<void> handleProactiveTrigger(String? payload) async {
    lastUserInteraction = DateTime.now();

    if (payload == null || payload.trim().isEmpty) return;
    if (!engineReady) {
      debugPrint('AuraBarBrain: proactive trigger ignored — engine not ready');
      return;
    }
    if (_isProcessing || userIsTyping || AuraTTSService.instance.isPlaying) {
      debugPrint('AuraBarBrain: proactive trigger deferred — busy');
      return;
    }

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

    try {
      final context = await auraGetProactiveContext();
      if (context.isNotEmpty) {
        buffer.writeln('  memory_context=$context');
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
