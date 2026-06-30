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
      _pendingPrompt = trimmed;
      _pendingPromptSource = source;
      await showProcessingTransition('Warming up AURA...');
      return;
    }

    if (_isProcessing) {
      _pendingPrompt = trimmed;
      _pendingPromptSource = source;
      debugPrint('AuraBarBrain: busy — queueing prompt');
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
        unawaited(VisionService.instance.captureNow(reason: 'user_ask'));
      }

      await _runGeneration(normalized.english, proactive: false);
    } catch (e, st) {
      debugPrint('AuraBarBrain: processUserPrompt error: $e\n$st');
      _releaseProcessingLock();
      await _updateBar(BarState.idle, message: 'Sorry, something went wrong.');
      _resumeWakeWordIfEnabled();
    }
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
