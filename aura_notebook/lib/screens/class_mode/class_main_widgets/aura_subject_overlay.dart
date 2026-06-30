import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';

part 'aura_subject_overlay/overlay_widgets.dart';
part 'aura_subject_overlay/dots.dart';

const _kThinkingSentinel = '\x00__THINKING__\x00';

const _kSuggestions = [
  '📐 Explain Pythagoras theorem',
  '⚗️ What is photosynthesis?',
  '🌍 Brief overview of World War II',
  '🔢 How does prime factorisation work?',
];

class AuraSubjectOverlay extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;
  const AuraSubjectOverlay({super.key, required this.open, required this.onClose});
  @override
  State<AuraSubjectOverlay> createState() => _AuraSubjectOverlayState();
}

class _AuraSubjectOverlayState extends State<AuraSubjectOverlay>
    with TickerProviderStateMixin {

  late final AnimationController _entry;
  late final Animation<double>   _slide, _fade;
  late final AnimationController _orb;

  final _ctrl       = TextEditingController();
  final _focus      = FocusNode();
  final _scroll     = ScrollController();
  final _streamText = ValueNotifier<String>('');
  final _thinking   = ValueNotifier<bool>(false);
  final _streaming  = ValueNotifier<bool>(false);

  bool    _busy    = false;
  bool    _hasText = false;
  bool    _jumpScheduled = false;
  String? _answer;

  Timer? _typewriterTimer;
  final List<String> _typewriterQueue = [];
  final StringBuffer _displayedBuffer = StringBuffer();
  bool _generationFinished = false;

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_typewriterQueue.isNotEmpty) {
        int charsToPop = 1;
        if (_typewriterQueue.length > 80) {
          charsToPop = 4;
        } else if (_typewriterQueue.length > 40) {
          charsToPop = 3;
        } else if (_typewriterQueue.length > 15) {
          charsToPop = 2;
        }

        for (int i = 0; i < charsToPop && _typewriterQueue.isNotEmpty; i++) {
          _displayedBuffer.write(_typewriterQueue.removeAt(0));
        }

        _streamText.value = '$_displayedBuffer▍';
        _jumpToBottom();
      } else if (_generationFinished) {
        timer.cancel();
        final text = _displayedBuffer.toString();
        _streamText.value = text;
        _answer = text;
        _busy = false;
        _thinking.value = false;
        _streaming.value = false;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _slide = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _fade  = CurvedAnimation(parent: _entry, curve: Curves.easeIn);
    _orb   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800))..repeat();
    _ctrl.addListener(() {
      final h = _ctrl.text.isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void didUpdateWidget(AuraSubjectOverlay old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _entry.forward();
      Future.delayed(const Duration(milliseconds: 320),
              () { if (mounted) _focus.requestFocus(); });
    } else if (!widget.open && old.open) {
      _entry.reverse();
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _entry.dispose(); _orb.dispose();
    _typewriterTimer?.cancel();
    _ctrl.dispose(); _focus.dispose(); _scroll.dispose();
    _streamText.dispose(); _thinking.dispose(); _streaming.dispose();
    super.dispose();
  }
  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _busy) return;
    _busy = true;
    _ctrl.clear();

    setState(() { _hasText = false; _answer = null; });
    HapticFeedback.lightImpact();

    _streamText.value = '';
    _thinking.value   = true;
    _streaming.value  = true;
    _displayedBuffer.clear();
    _typewriterQueue.clear();
    _generationFinished = false;
    _startTypewriter();

    try {
      await for (final token in auraChat(prompt: 'Teacher mode: $q')) {
        if (!mounted) return;
        if (token == _kThinkingSentinel) continue;
        if (_thinking.value) _thinking.value = false;

        for (final rune in token.runes) {
          _typewriterQueue.add(String.fromCharCode(rune));
        }
      }
    } catch (e) {
      debugPrint('overlay err: $e');
      _generationFinished = true;
    } finally {
      _generationFinished = true;
    }
  }
  void _jumpToBottom() {
    if (_jumpScheduled || !_scroll.hasClients) return;
    _jumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpScheduled = false;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entry,
      builder: (_, __) {
        if (_entry.value == 0) return const SizedBox.shrink();
        return Stack(children: [
          // Scrim
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
                color: Colors.black.withOpacity(0.6 * _fade.value)),
          ),
          // Panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero).animate(_slide),
              child: FadeTransition(
                  opacity: _fade, child: _buildPanel(context)),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    // Key fix: bottom padding for keyboard, but input bar is ALWAYS in column
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top:   BorderSide(color: Color(0x447C4DFF)),
          left:  BorderSide(color: Color(0x227C4DFF)),
          right: BorderSide(color: Color(0x227C4DFF)),
        ),
      ),
      // Use padding for keyboard — keeps input always visible
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Handle(),
          _Header(orb: _orb, onClose: widget.onClose),
          Flexible(child: _body()),
          // ── Input bar — ALWAYS rendered, never hidden ──────────────────
          _InputBar(
            controller: _ctrl,
            focusNode: _focus,
            hasText: _hasText,
            busy: _busy,
            onSend: _send,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _body() {
    final hasContent = _answer != null;
    return ValueListenableBuilder<bool>(
      valueListenable: _streaming,
      builder: (_, isStreaming, __) {
        // Empty state — suggestions
        if (!hasContent && !isStreaming) {
          return ValueListenableBuilder<bool>(
            valueListenable: _thinking,
            builder: (_, thinking, __) =>
            thinking ? const _ThinkingWidget() : _Suggestions(
              suggestions: _kSuggestions,
              onSelected: (t) { _ctrl.text = t; _send(); },
            ),
          );
        }
        // Streaming or committed answer
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: isStreaming
              ? ValueListenableBuilder<bool>(
            valueListenable: _thinking,
            builder: (_, thinking, __) => thinking
                ? const _ThinkingWidget()
                : ValueListenableBuilder<String>(
              valueListenable: _streamText,
              builder: (_, txt, __) => _AnswerBubble(text: txt),
            ),
          )
              : _AnswerBubble(text: _answer!),
        );
      },
    );
  }
}
