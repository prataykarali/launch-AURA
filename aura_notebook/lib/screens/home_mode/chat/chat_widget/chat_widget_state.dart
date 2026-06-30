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
}
