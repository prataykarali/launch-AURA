part of 'bar_brain.dart';

const int kBarMaxChars = 140;
const int kBarMaxWords = 28;

extension AuraBarBrainPrompt on AuraBarBrain {
  Future<void> processUserPrompt(
    String text, {
    AuraObservationSource source = AuraObservationSource.text,
  }) async {
    lastUserInteraction = DateTime.now();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!engineReady) {
      _promptQueue.add(_QueuedPrompt(trimmed, source));
      await showProcessingTransition('Warming up AURA...');
      return;
    }

    if (_isProcessing) {
      if (_promptQueue.length >= AuraBarBrain._kMaxQueueSize) {
        _promptQueue.removeAt(0); // Drop oldest to make room.
      }
      _promptQueue.add(_QueuedPrompt(trimmed, source));
      debugPrint('AuraBarBrain: busy — queued prompt (${_promptQueue.length} pending)');
      await _updateBar(BarState.processing, message: 'Queued (${_promptQueue.length})...');
      return;
    }

    _isProcessing = true;
    _processingStartedAt = DateTime.now();
    _processingLock = Completer<void>();
    _isProactive = false;
    _clearProactiveTrigger();
    _currentResponse = '';
    _sentenceBuffer = '';

    _startThinkingAnimation();

    try {
      final normalized = await NaturalContextService.instance.normalizeUserInput(
        trimmed,
        source: source,
        proactiveCandidate: source == AuraObservationSource.speech,
      );

      if (source == AuraObservationSource.text &&
          VisionService.instance.shouldTriggerCapture(normalized.english)) {
        await _updateBar(BarState.watching, message: 'AURA is watching...');
        unawaited(VisionService.instance.captureNow(reason: 'user_ask'));
      }

      // Build prompt with length hint for the small model.
      final prompt = _buildPromptWithLengthHint(normalized.english);
      await _runGeneration(prompt, proactive: false);
    } catch (e, st) {
      debugPrint('AuraBarBrain: processUserPrompt error: $e\n$st');
      _releaseProcessingLock();
      await _updateBar(BarState.idle, message: 'Sorry, something went wrong.');
      _resumeWakeWordIfEnabled();
    }
  }

  /// Add a length hint to help the small model calibrate response length.
  String _buildPromptWithLengthHint(String prompt) {
    final wordCount = prompt.split(RegExp(r'\s+')).length;
    // Simple factual questions (short prompts) → short answer.
    if (wordCount <= 4 && !prompt.contains('?')) {
      return '$prompt Answer in 1-2 sentences.';
    }
    if (wordCount <= 6) {
      return '$prompt Give a brief, clear answer in 2-3 sentences.';
    }
    // Complex open-ended questions → allow longer but structured.
    if (prompt.length > 100) {
      return '$prompt Give a thoughtful but concise answer in 3-4 sentences.';
    }
    return prompt;
  }

  // ── Response sanitization ──────────────────────────────────────────────────
  //
  // Remove model artifacts and accidental echoes of the prompt from the
  // streaming response so the bar text stays clean.
  String _sanitizeBarResponse(String text, {required String prompt}) {
    var cleaned = text.trim();

    // Strip the thinking sentinel if it ever leaks through.
    cleaned = cleaned.replaceAll('\x00__THINKING__\x00', '');

    // Remove common role prefixes (case-insensitive, one pass).
    const prefixes = ['AURA:', 'AURA,', 'AURA says:', 'Assistant:', 'Assistant,'];
    final lower = cleaned.toLowerCase();
    for (final prefix in prefixes) {
      if (lower.startsWith(prefix.toLowerCase())) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }

    // Drop an echoed copy of the prompt from the beginning.
    final p = prompt.trim();
    if (p.isNotEmpty && cleaned.toLowerCase().startsWith(p.toLowerCase())) {
      cleaned = cleaned.substring(p.length).trim();
      if (cleaned.startsWith('?') ||
          cleaned.startsWith('.') ||
          cleaned.startsWith(',')) {
        cleaned = cleaned.substring(1).trim();
      }
    }

    // Strip proactive trigger context echoes. The small model sometimes
    // echoes the internal proactive prompt back mid-response:
    //   "Sure thing. ... I remember we were talking about AURA is being
    //    proactive. Context: trigger_label=idle_checkin..."
    final proactiveMarkers = [
      'i remember we were talking about aura is being proactive',
      'aura is being proactive',
      'trigger_label=',
      'trigger_type=',
      'memory_context=',
      'context:',
      'schedule request:',
      'observed:',
      'guidance:',
      'the user has shown repeated',
      'the user appears to be',
      'make a gentle personalized',
      'offer one brief help',
    ];
    for (final marker in proactiveMarkers) {
      final idx = cleaned.toLowerCase().indexOf(marker);
      if (idx >= 0) {
        final before = cleaned.substring(0, idx).trimRight();
        if (before.split(' ').where((w) => w.isNotEmpty).length >= 3) {
          cleaned = before;
        } else {
          cleaned = '';
        }
      }
    }

    return cleaned;
  }

  // Heuristic used by the bar text field and by callers that want to decide
  // whether a request belongs in the main chat instead of the compact bar.
  bool shouldOpenMainChat(String text) {
    final trimmed = text.trim();
    final wordCount = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return trimmed.length > kBarMaxChars || wordCount > kBarMaxWords;
  }
}
