part of 'bar_brain.dart';

const String _kBarSuffix = ' [BAR]';

extension AuraBarBrainGeneration on AuraBarBrain {
  Future<void> _runGeneration(String prompt, {required bool proactive}) async {
    if (_ttsEnabled) {
      AuraTTSService.instance.setPlaybackSuppressed(false);
    }

    final enginePrompt = proactive ? prompt : '$prompt$_kBarSuffix';
    final stream = auraChat(prompt: enginePrompt);
    final barStateStreaming = proactive
        ? BarState.proactive
        : BarState.speaking;

    // Backup safety net: if the Rust engine doesn't emit any token within
    // a reasonable window, cancel the stream and return to idle so the user
    // isn't stuck on "Just a moment..." forever. On low-end Android devices
    // the first token of a 1.2B Q4 model can take 15-30s, so use a longer
    // first-token timeout on mobile.
    final firstTokenTimeout = Platform.isAndroid
        ? const Duration(seconds: 90)
        : const Duration(seconds: 16);
    final interTokenTimeout = const Duration(seconds: 40);
    Timer? generationTimeout;
    var firstTokenReceived = false;
    generationTimeout = Timer(firstTokenTimeout, () {
      debugPrint('[AURA] Generation timeout — cancelling from Flutter');
      auraCancel();
      _chatSubscription?.cancel();
      _chatSubscription = null;
      _releaseProcessingLock();
      _updateBar(BarState.idle, message: 'AURA took too long. Please try again.');
      _resumeWakeWordIfEnabled();
    });

    _chatSubscription = stream.listen(
      (token) {
        if (!firstTokenReceived) {
          firstTokenReceived = true;
          debugPrint('[AURA] First token received after ${firstTokenTimeout.inSeconds}s safety window');
        }
        // Reset the inter-token watchdog after each token so a long first
        // token is allowed but subsequent stalls still get cancelled quickly.
        generationTimeout?.cancel();
        generationTimeout = Timer(interTokenTimeout, () {
          debugPrint('[AURA] Inter-token timeout — cancelling from Flutter');
          auraCancel();
          _chatSubscription?.cancel();
          _chatSubscription = null;
          _releaseProcessingLock();
          _updateBar(BarState.idle, message: 'AURA stalled. Please try again.');
          _resumeWakeWordIfEnabled();
        });
        _stopThinkingAnimation();
        if (token == '\x00__THINKING__\x00') return;
        _currentResponse += token;
        _currentResponse = _sanitizeBarResponse(
          _currentResponse,
          prompt: prompt,
        );
        _currentResponse = _clampBarSentences(_currentResponse);
        if (_isSilentProactiveText(_currentResponse)) {
          generationTimeout?.cancel();
          generationTimeout = null;
          auraCancel();
          _chatSubscription?.cancel();
          _chatSubscription = null;
          _currentResponse = '';
          _sentenceBuffer = '';
          _releaseProcessingLock();
          _updateBar(BarState.idle);
          _resumeWakeWordIfEnabled();
          return;
        }
        _sentenceBuffer += token;
        _sentenceBuffer = _sanitizeBarResponse(_sentenceBuffer, prompt: prompt);
        _sentenceBuffer = _clampBarSentences(_sentenceBuffer);

        if (_hasTooManyVisibleBeats(_currentResponse)) {
          auraCancel();
        }

        // Proactive popups must stay compact, but not robotic. User prompts
        // are already filtered before generation; never cancel a valid STT/text
        // answer mid-stream.
        if (_isProactive && _currentResponse.length > 220) {
          debugPrint('[AURA] Proactive response too long — truncating');
          generationTimeout?.cancel();
          generationTimeout = null;
          auraCancel();
          _chatSubscription?.cancel();
          _chatSubscription = null;
          return;
        }

        // Flush completed clauses/sentences to TTS. Rust appends a tiny
        // punctuation-based silence tail so speech breathes naturally while the
        // next chunk is already being synthesized.
        _flushPunctuationChunks(proactive: proactive);
        _flushEarlySpeech(proactive: proactive);
        _streamUpdate(barStateStreaming, _visibleBarBeats(_currentResponse));
      },
      onError: (err) {
        generationTimeout?.cancel();
        generationTimeout = null;
        _stopThinkingAnimation();
        debugPrint('AuraBarBrain: LLM stream error: $err');
        _releaseProcessingLock();
        _updateBar(BarState.idle, message: 'Error generating response.');
        _resumeWakeWordIfEnabled();
      },
      onDone: () async {
        generationTimeout?.cancel();
        generationTimeout = null;
        _stopThinkingAnimation();
        _releaseProcessingLock();
        debugPrint(
          'AuraBarBrain: LLM stream done. Response: $_currentResponse',
        );

        // Final coalesced push.
        _barFlushTimer?.cancel();
        _barFlushTimer = null;
        if (_currentResponse.isNotEmpty) {
          if (_isSilentProactiveText(_currentResponse)) {
            _currentResponse = '';
            _sentenceBuffer = '';
            await _updateBar(BarState.idle);
            _resumeWakeWordIfEnabled();
            return;
          }
          await _updateBar(
            barStateStreaming,
            message: _visibleBarBeats(_currentResponse),
          );
        }

        // Flush any trailing sentence — NEVER subject to the char budget, so
        // the tail of every response always speaks (no "silent TTS").
        if (_sentenceBuffer.trim().isNotEmpty) {
          final rest = _sentenceBuffer.trim();
          _sentenceBuffer = '';
          if (_ttsEnabled) {
            unawaited(AuraTTSService.instance.speak(rest));
          }
        }

        if (_currentResponse.isEmpty) {
          await _updateBar(BarState.idle);
          _resumeWakeWordIfEnabled();
        } else {
          // Stay in the active display state while TTS plays, THEN fade to
          // idle. Proactive turns must remain `proactive` so Android keeps the
          // response in the bubble instead of collapsing into a plain waveform.
          //
          // Proactive: cap at 7 s so natural popups can breathe without making
          // the bar feel stuck. The user can
          // always tap the bubble to dismiss early (see aura_bar.dart onTap).
          // User turns: cap at 8 s (was 12 s) — shorter feels more responsive.
          _responseFadeTimer?.cancel();
          await _updateBar(
            barStateStreaming,
            message: _visibleBarBeats(_currentResponse),
          );
          unawaited(_storeProactiveNotebookNote(_currentResponse));
          final ttsMs = _isProactive
              ? (_currentResponse.length * 55).clamp(2500, 7000)
              : (_currentResponse.length * 55).clamp(2500, 8000);
          _responseFadeTimer = Timer(Duration(milliseconds: ttsMs), () {
            _updateBar(BarState.idle);
            _resumeWakeWordIfEnabled();
          });
        }
      },
    );
  }

  // ── _flushPunctuationChunks ───────────────────────────────────────────────
  //
  // Speak completed clauses/sentences during streaming on every platform. This
  // keeps latency low while allowing comma/period/ellipsis pauses to happen in
  // the audio queue rather than inside text generation.
  void _flushPunctuationChunks({required bool proactive}) {
    if (!_ttsEnabled) return;

    final minChars = proactive ? 18 : 24;
    final exp = RegExp(r'(.+?(?:\.\.\.|…|—|[.!?]|\n\n|,))', dotAll: true);
    final matches = exp.allMatches(_sentenceBuffer).toList();
    if (matches.isEmpty) return;

    var endIdx = 0;
    for (final match in matches) {
      final chunk = _sentenceBuffer.substring(endIdx, match.end).trim();
      final isStrongBoundary =
          chunk.endsWith('.') ||
          chunk.endsWith('!') ||
          chunk.endsWith('?') ||
          chunk.endsWith('...') ||
          chunk.endsWith('…') ||
          chunk.endsWith('—') ||
          chunk.endsWith('\n\n');
      if (!isStrongBoundary && chunk.length < minChars) {
        break;
      }
      endIdx = match.end;
    }
    if (endIdx == 0) return;

    final completedText = _sentenceBuffer.substring(0, endIdx);
    _sentenceBuffer = _sentenceBuffer.substring(endIdx);

    unawaited(AuraTTSService.instance.speak(completedText));
  }

  void _flushEarlySpeech({required bool proactive}) {
    if (!_ttsEnabled) return;
    final trimmed = _sentenceBuffer.trimLeft();
    if (trimmed.isEmpty) return;
    if (trimmed.contains(RegExp(r'[.!?\n]'))) return;

    final minWords = proactive ? 6 : 8;
    final maxChars = proactive ? 64 : 88;
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length < minWords && trimmed.length < maxChars) return;

    final cut = _earlySpeechCut(
      trimmed,
      minWords: minWords,
      maxChars: maxChars,
    );
    if (cut == null) return;
    _sentenceBuffer = trimmed.substring(cut.length).trimLeft();
    unawaited(AuraTTSService.instance.speak(cut));
  }

  String? _earlySpeechCut(
    String text, {
    required int minWords,
    required int maxChars,
  }) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length < minWords && text.length < maxChars) return null;
    var count = 0;
    var end = 0;
    for (final match in RegExp(r'\S+').allMatches(text)) {
      count++;
      end = match.end;
      if (count >= minWords && end >= maxChars * 0.65) break;
      if (end >= maxChars) break;
    }
    if (count < minWords && end < maxChars) return null;
    return text.substring(0, end).trim();
  }

  bool _isSilentProactiveText(String text) {
    if (!_isProactive) return false;
    final normalized = text.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    return normalized == 'SILENT';
  }

  String _clampBarSentences(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return trimmed;

    final matches = RegExp(r'[^.!?\n]+[.!?\n]+').allMatches(trimmed).toList();
    if (matches.length >= 4) {
      return trimmed.substring(0, matches[3].end).trim();
    }

    const maxChars = 420;
    if (trimmed.length <= maxChars) return trimmed;
    final cut = trimmed.substring(0, maxChars);
    final lastSpace = cut.lastIndexOf(' ');
    return '${cut.substring(0, lastSpace > 80 ? lastSpace : maxChars).trim()}...';
  }

  bool _hasTooManyVisibleBeats(String text) {
    return RegExp(r'[^.!?\n]+[.!?\n]+').allMatches(text).length >= 4;
  }

  String _visibleBarBeats(String text) {
    final sentences = RegExp(r'[^.!?\n]+[.!?\n]+')
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return text;
    if (sentences.length <= 2) return sentences.join(' ');
    return sentences.skip(sentences.length - 2).join(' ');
  }

  Future<void> _storeProactiveNotebookNote(String response) async {
    if (!_isProactive) return;
    if (_isSilentProactiveText(response)) return;

    final title = switch (_currentTriggerType) {
      'vision' => 'Vision',
      'speech' => 'Proactive',
      'text' => 'Proactive',
      _ => 'Proactive',
    };
    final event = _currentTriggerData?['event'];
    final summary = event is Map ? event['summary']?.toString().trim() : null;
    final cleaned = response.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return;
    final content = summary == null || summary.isEmpty
        ? cleaned
        : '$cleaned\nObserved: $summary';
    try {
      await auraAddMemoryNote(title: title, content: content, pinned: false);
    } catch (e) {
      debugPrint('AuraBarBrain: failed to store proactive note: $e');
    }
  }
}
