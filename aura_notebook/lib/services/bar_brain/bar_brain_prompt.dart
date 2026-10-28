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

    if (trimmed.startsWith('/')) {
      await _handleBarSlashCommand(trimmed);
      return;
    }

    // ── Bandit RL engagement signal ──────────────────────────────────────
    // If a proactive trigger fired recently and the user is now sending a
    // message within the 30s engagement window, that counts as "engaged".
    // This is the learning signal that makes the bandit actually learn.
    if (_pendingEngagementTriggerId != null) {
      _recordEngagement(true);
    }

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
      debugPrint(
        'AuraBarBrain: busy — queued prompt (${_promptQueue.length} pending)',
      );
      await _updateBar(
        BarState.processing,
        message: 'Queued (${_promptQueue.length})...',
      );
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
      final normalized = await NaturalContextService.instance
          .normalizeUserInput(
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

      // After generation completes, memory processing on the Rust side has
      // extracted and stored any schedule notes. Force an immediate schedule
      // check so timers are created right away instead of waiting for the
      // next 15-30 min scheduler cycle (Issue #9).
      // Delay 2s to ensure the Rust-side memory processing (which runs
      // asynchronously after the stream completes) has finished storing
      // the schedule note before we check for it.
      if (normalized.english.toLowerCase().contains('remind') ||
          normalized.english.toLowerCase().contains('schedule') ||
          normalized.english.toLowerCase().contains('wake me')) {
        Future.delayed(const Duration(seconds: 2), () {
          unawaited(ProactiveScheduler.instance.forceScheduleCheck());
        });
      }
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
    const prefixes = [
      'AURA:',
      'AURA,',
      'AURA says:',
      'Assistant:',
      'Assistant,',
    ];
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

  Future<void> _handleBarSlashCommand(String text) async {
    _isProcessing = true;
    _processingStartedAt = DateTime.now();
    _processingLock = Completer<void>();
    _currentResponse = '';
    _sentenceBuffer = '';

    await _updateBar(BarState.processing, message: 'Running command...');

    String result = '';
    if (text.startsWith('/see')) {
      await _updateBar(BarState.watching, message: 'AURA is scanning...');

      String? ocrText;
      try {
        await VisionService.instance.captureNow(reason: 'user_ask');
        ocrText = VisionService.instance.lastScreenText;
      } catch (e) {
        debugPrint('Screen OCR failed: $e');
      }

      String? webcamScene;
      if (Platform.isLinux) {
        try {
          await auraStartWebcamThread();
          await Future.delayed(const Duration(milliseconds: 1800));
          webcamScene = await auraGetLatestWebcamScene();
          await auraStopWebcamThread();
        } catch (e) {
          debugPrint('Webcam YOLO failed: $e');
        }
      }

      final items = <String>[];
      if (ocrText != null && ocrText.isNotEmpty) {
        final screenSummary = ocrText.length > 80
            ? '${ocrText.substring(0, 80)}...'
            : ocrText;
        items.add('Screen: $screenSummary');
      } else {
        items.add('Screen: empty');
      }
      if (webcamScene != null &&
          webcamScene.isNotEmpty &&
          !webcamScene.contains('No visual scene summary')) {
        items.add(webcamScene);
      }
      result = items.join('. ');
    } else if (text.startsWith('/reminder')) {
      if (text.length <= 10) {
        result = 'Format: /reminder [time] [text]';
      } else {
        final content = text.substring(10).trim();
        final shorthandMatch = RegExp(
          r'^(\d+)(s|m|h)\s+(.+)$',
        ).firstMatch(content);
        String finalRequest = '';
        if (shorthandMatch != null) {
          final amount = shorthandMatch.group(1);
          final unitChar = shorthandMatch.group(2);
          final reminderText = shorthandMatch.group(3);
          final unit = unitChar == 's'
              ? 'seconds'
              : (unitChar == 'm' ? 'minutes' : 'hours');
          finalRequest =
              'Schedule request: remind me to $reminderText in $amount $unit';
        } else {
          if (content.toLowerCase().startsWith('in ') ||
              content.toLowerCase().contains('at ')) {
            finalRequest = 'Schedule request: $content';
          } else {
            finalRequest = 'Schedule request: remind me to $content';
          }
        }

        try {
          await auraAddMemoryNote(
            title: 'Schedule',
            content: finalRequest,
            pinned: false,
          );
          unawaited(ProactiveScheduler.instance.forceScheduleCheck());
          result =
              'Reminder scheduled: "${finalRequest.replaceAll('Schedule request: ', '')}"';
        } catch (e) {
          result = 'Failed to schedule: $e';
        }
      }
    } else {
      result = 'Unknown command: $text';
    }

    _isProcessing = false;
    _processingStartedAt = null;
    final lock = _processingLock;
    _processingLock = null;
    if (lock != null && !lock.isCompleted) lock.complete();

    await _updateBar(BarState.speaking, message: result);

    final cleanSpeak = result.replaceAll(RegExp(r'[*_#`]'), '');
    if (_ttsEnabled) {
      unawaited(AuraTTSService.instance.speak(cleanSpeak));
    }

    _responseFadeTimer?.cancel();
    _responseFadeTimer = Timer(const Duration(seconds: 6), () {
      _updateBar(BarState.idle);
      _resumeWakeWordIfEnabled();
    });
  }
}
