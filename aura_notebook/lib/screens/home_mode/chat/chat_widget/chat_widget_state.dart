part of 'chat_widget.dart';

class _AuraChatWidgetState extends State<AuraChatWidget> {
  final _messages = <ChatMessage>[];
  final _streamText = ValueNotifier<String>('');
  final _streaming = ValueNotifier<bool>(false);
  final _thinking = ValueNotifier<bool>(false);
  final _busyNotifier = ValueNotifier<bool>(false);
  final _scroll = ScrollController();

  StreamSubscription<String>? _chatSub;
  bool _busy = false;
  bool _jumpScheduled = false;

  // ── Typewriter State ──────────────────────────────────────────────────────
  Timer? _typewriterTimer;
  final StringBuffer _displayedBuffer = StringBuffer();
  bool _generationFinished = false;
  bool _firstRealToken = true;
  String _currentPrompt = '';
  final StringBuffer _generationBuffer = StringBuffer();
  // Streaming TTS: flush sentence chunks as they arrive, not after full reply.
  final StringBuffer _ttsSentenceBuffer = StringBuffer();

  @override
  void initState() {
    super.initState();
    // Ensure TTS suppression is cleared when launching the chat screen
    AuraTTSService.instance.setPlaybackSuppressed(false);
  }

  Future<void> _send(
    String text, {
    AuraObservationSource source = AuraObservationSource.text,
  }) async {
    if (text.isEmpty || _busy) return;

    // Stop any ongoing speech from a previous turn so the new reply doesn't
    // overlap with the user starting their next chat.
    unawaited(AuraTTSService.instance.stop());

    // Notebook shortcut
    if (text.toLowerCase().contains('notebook')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => NotebookPage()));
      return;
    }

    if (text.trim().startsWith('/')) {
      await _handleSlashCommand(text.trim());
      return;
    }

    _busy = true;
    _busyNotifier.value = true;
    HapticFeedback.lightImpact();

    final normalized = await NaturalContextService.instance.normalizeUserInput(
      text,
      source: source,
    );
    final engineText = normalized.english.trim();
    if (engineText.isEmpty) {
      _busy = false;
      _busyNotifier.value = false;
      return;
    }

    unawaited(
      AuraBarMultiWindowService.instance.sendState(BarState.processing),
    );

    await WakelockPlus.enable();

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _scheduleJump();

    _currentPrompt = engineText;
    _firstRealToken = true;
    _displayedBuffer.clear();
    _generationBuffer.clear();
    _generationFinished = false;
    _typewriterTimer?.cancel();

    _streamText.value = '▍';
    _streaming.value = true;
    _thinking.value = true;

    // Maintain BarState.processing while thinking/streaming
    unawaited(
      AuraBarMultiWindowService.instance.sendState(BarState.processing),
    );

    _startTypewriter(isThinkingPhase: true);

    await Future.delayed(const Duration(milliseconds: 10));

    Future.delayed(const Duration(seconds: 120), () {
      if (_busy && mounted) {
        debugPrint('FORCE_UNLOCK: releasing stuck busy flag');
        _forceCompleteTypewriter(
          _generationBuffer.isNotEmpty
              ? _generationBuffer.toString()
              : '⚠️ No response.',
        );
      }
    });

    final Stream<String> stream = engineText.length > kChunkThreshold
        ? auraChatChunked(chunks: chunkMessage(engineText))
        : auraChat(prompt: engineText);

    try {
      _chatSub = stream.listen(
        (token) {
          if (token == kThinkingSentinel) {
            _thinking.value = true;
            return;
          }

          if (_firstRealToken) {
            _firstRealToken = false;
            _thinking.value = false;
            _displayedBuffer.clear();
            _startTypewriter(isThinkingPhase: false);
            unawaited(
              AuraBarMultiWindowService.instance.sendState(BarState.speaking),
            );
          }

          _generationBuffer.write(token);
          _ttsSentenceBuffer.write(token);
          _flushStreamingTts();
        },
        onError: (Object err) {
          debugPrint('stream error: $err');
          _generationFinished = true;
          _forceCompleteTypewriter(
            _generationBuffer.isNotEmpty
                ? _generationBuffer.toString()
                : '⚠️ Something went wrong.',
          );
        },
        onDone: () {
          debugPrint('STREAM_DONE: ${_generationBuffer.length} chars');
          _generationFinished = true;
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('send error: $e');
      _generationFinished = true;
      _forceCompleteTypewriter(
        _generationBuffer.isNotEmpty
            ? _generationBuffer.toString()
            : '⚠️ Engine error.',
      );
    }
  }

  // ── Stop ──────────────────────────────────────────────────────────────────

  Future<void> _stop() async {
    auraCancel();
    await _chatSub?.cancel();
    _typewriterTimer?.cancel();

    unawaited(AuraBarMultiWindowService.instance.sendState(BarState.idle));

    if (_busy) {
      final textToCommit = _displayedBuffer.isNotEmpty
          ? _displayedBuffer.toString()
          : _streamText.value.replaceAll('▍', '');
      _commitBubble(textToCommit.isNotEmpty ? textToCommit : '⚠️ Cancelled.');
    }
  }

  // ── Streaming TTS ──────────────────────────────────────────────────────────
  // Flush completed clauses/sentences to TTS during streaming so speech starts
  // before the full response is generated. Same pattern as the AURA bar.
  void _flushStreamingTts() {
    final buffer = _ttsSentenceBuffer.toString();
    if (buffer.trim().length < 6) return;

    // Flush on ANY punctuation boundary — commas, periods, question marks,
    // exclamation, newlines. Lower threshold so speech starts ASAP.
    final exp = RegExp(r'(.+?(?:\.\.\.|…|—|[.!?]|\n|,))', dotAll: true);
    final matches = exp.allMatches(buffer).toList();
    if (matches.isEmpty) return;

    // Take all completed chunks at once.
    final completedText = buffer.substring(0, matches.last.end);
    _ttsSentenceBuffer.clear();
    _ttsSentenceBuffer.write(buffer.substring(matches.last.end));

    if (completedText.trim().isNotEmpty) {
      unawaited(AuraTTSService.instance.speak(completedText.trim()));
    }
  }

  // ── Commit bubble ─────────────────────────────────────────────────────────

  void _commitBubble(String text) {
    _busy = false;
    _busyNotifier.value = false;

    unawaited(AuraBarMultiWindowService.instance.sendState(BarState.idle));

    if (!mounted) {
      WakelockPlus.disable();
      return;
    }

    _streamText.value = '';
    _streaming.value = false;
    _thinking.value = false;

    if (text.isNotEmpty) {
      setState(() => _messages.add(ChatMessage(text: text, isUser: false)));
      // Flush any trailing text that wasn't spoken during streaming.
      final trailing = _ttsSentenceBuffer.toString().trim();
      _ttsSentenceBuffer.clear();
      if (trailing.isNotEmpty) {
        unawaited(AuraTTSService.instance.speak(trailing));
      }
    }

    WakelockPlus.disable();
    _scheduleJump();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _chatSub?.cancel();
    _typewriterTimer?.cancel();
    _streamText.dispose();
    _streaming.dispose();
    _thinking.dispose();
    _busyNotifier.dispose();
    _scroll.dispose();
    // Stop any ongoing speech when leaving the chat screen
    AuraTTSService.instance.stop();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: MsgList(
          messages: _messages,
          streamText: _streamText,
          streaming: _streaming,
          scroll: _scroll,
          onSuggestion: (text) => _send(text),
        ),
      ),
      ThinkingIndicator(thinking: _thinking),
      InputBar(onSend: _send, onStop: _stop, busy: _busyNotifier),
    ],
  );

  Future<void> _handleSlashCommand(String text) async {
    _busy = true;
    _busyNotifier.value = true;
    HapticFeedback.lightImpact();
    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _scheduleJump();

    String result = '';
    if (text.trim().startsWith('/see')) {
      setState(
        () => _messages.add(
          const ChatMessage(
            text: 'AURA is scanning screen and webcam...',
            isUser: false,
          ),
        ),
      );
      _scheduleJump();

      result = await _runOnDemandSee();

      if (_messages.isNotEmpty &&
          _messages.last.text == 'AURA is scanning screen and webcam...') {
        setState(() {
          _messages.removeLast();
        });
      }
    } else if (text.trim().startsWith('/reminder')) {
      result = await _runOnDemandReminder(text.trim());
    } else {
      result = 'Unknown slash command. Supported: /see, /reminder';
    }

    setState(() => _messages.add(ChatMessage(text: result, isUser: false)));
    _scheduleJump();

    final cleanSpeak = result.replaceAll(RegExp(r'[*_#`]'), '');
    unawaited(AuraTTSService.instance.speak(cleanSpeak));

    _busy = false;
    _busyNotifier.value = false;
  }

  Future<String> _runOnDemandSee() async {
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

    final buffer = StringBuffer();
    if (ocrText != null && ocrText.isNotEmpty) {
      buffer.writeln('🖥️ **On your screen:**');
      final truncated = ocrText.length > 300
          ? '${ocrText.substring(0, 300)}...'
          : ocrText;
      buffer.writeln(truncated);
    } else {
      buffer.writeln('🖥️ No text detected on your screen.');
    }

    buffer.writeln('');

    if (Platform.isLinux) {
      if (webcamScene != null &&
          webcamScene.isNotEmpty &&
          !webcamScene.contains('No visual scene summary')) {
        buffer.writeln('📷 **From the webcam:**');
        buffer.writeln(webcamScene);
      } else {
        buffer.writeln('📷 No objects detected by webcam.');
      }
    } else {
      buffer.writeln('📷 Webcam is only supported on Linux.');
    }

    return buffer.toString().trim();
  }

  Future<String> _runOnDemandReminder(String text) async {
    final cmd = text.trim();
    if (cmd.length <= 10) {
      return 'Format: /reminder [time] [text] (e.g., /reminder 5m drink water)';
    }
    final content = cmd.substring(10).trim();

    final shorthandMatch = RegExp(r'^(\d+)(s|m|h)\s+(.+)$').firstMatch(content);
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
      return '🔔 Reminder scheduled: "${finalRequest.replaceAll('Schedule request: ', '')}"';
    } catch (e) {
      return '⚠️ Failed to schedule reminder: $e';
    }
  }
}
