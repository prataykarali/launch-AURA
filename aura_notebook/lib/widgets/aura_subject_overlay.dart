import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SENTINEL & SUGGESTIONS
// ─────────────────────────────────────────────────────────────────────────────
const _kThinkingSentinel = '\x00__THINKING__\x00';

const _kSuggestions = [
  '📐 Explain Pythagoras theorem',
  '⚗️ What is photosynthesis?',
  '🌍 Brief overview of World War II',
  '🔢 How does prime factorisation work?',
];

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class AuraSubjectOverlay extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const AuraSubjectOverlay({
    super.key,
    required this.open,
    required this.onClose,
  });

  @override
  State<AuraSubjectOverlay> createState() => _AuraSubjectOverlayState();
}

class _AuraSubjectOverlayState extends State<AuraSubjectOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  late final AnimationController _orb;

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  final _streamText = ValueNotifier<String>('');
  final _thinking = ValueNotifier<bool>(false);
  final _streaming = ValueNotifier<bool>(false);
  final _hasText = ValueNotifier<bool>(false);
  final _errorMsg = ValueNotifier<String?>(null);

  String? _answer;
  bool _busy = false;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeIn);

    _orb = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();

    _ctrl.addListener(() => _hasText.value = _ctrl.text.isNotEmpty);

    // FIX 1: If the widget is mounted with open=true (e.g. hot reload),
    // start the entry animation immediately so _entry.value != 0.
    if (widget.open) {
      _entry.forward();
      Future.delayed(
          const Duration(milliseconds: 320),
              () {
            if (mounted) _focus.requestFocus();
          });
    }
  }

  @override
  void didUpdateWidget(AuraSubjectOverlay old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _entry.forward();
      Future.delayed(
          const Duration(milliseconds: 320),
              () {
            if (mounted) _focus.requestFocus();
          });
    } else if (!widget.open && old.open) {
      _entry.reverse();
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _orb.dispose();
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    _streamText.dispose();
    _thinking.dispose();
    _streaming.dispose();
    _hasText.dispose();
    _errorMsg.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SEND
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _busy) return;

    _busy = true;
    _ctrl.clear();
    _hasText.value = false;
    _errorMsg.value = null;
    _streamText.value = '';
    _thinking.value = true;
    _streaming.value = true;
    setState(() => _answer = null);

    HapticFeedback.lightImpact();

    final buf = StringBuffer();
    try {
      await for (final token in auraChat(prompt: 'Teacher mode: $q')) {
        if (!mounted) break;
        if (token == _kThinkingSentinel) continue;

        if (_thinking.value) _thinking.value = false;

        for (var i = 0; i < token.length; i++) {
          buf.write(token[i]);
          _streamText.value = '${buf.toString()}▍';
          await Future.delayed(const Duration(milliseconds: 12));
          _scrollToBottom();
        }
      }

      // FIX 2: Reset _streaming BEFORE setState so the body's ValueListenableBuilder
      // sees streaming=false and _answer=non-null simultaneously — no blank frame.
      _streamText.value = buf.toString();
      _thinking.value = false;
      _streaming.value = false;
      if (mounted) setState(() => _answer = buf.toString());
    } catch (e, st) {
      debugPrint('AuraOverlay._send error:\n$e\n$st');
      _thinking.value = false;
      _streaming.value = false;
      if (mounted) {
        _errorMsg.value = 'AURA hit a snag — tap to retry.';
        setState(() => _answer = null);
      }
    } finally {
      // Guard: ensure busy is always released even if we break early.
      _busy = false;
    }
  }

  void _scrollToBottom() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // FIX 3: Never return SizedBox.shrink() — that kills the widget tree and
    // drops the AnimationController, causing the next open to lose its state.
    // Use Visibility(maintainState: true) instead, or simply let AnimatedBuilder
    // render a zero-size transparent widget during the collapsed state.
    return AnimatedBuilder(
      animation: _entry,
      builder: (_, __) {
        if (_entry.isDismissed) return const SizedBox.shrink();
        return Stack(
          children: [
            // Scrim
            GestureDetector(
              onTap: widget.onClose,
              child:
              Container(color: Colors.black.withOpacity(0.6 * _fade.value)),
            ),
            // Panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_slide),
                child: FadeTransition(
                  opacity: _fade,
                  child: _buildPanel(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0x447C4DFF)),
          left: BorderSide(color: Color(0x227C4DFF)),
          right: BorderSide(color: Color(0x227C4DFF)),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _header(),
          Flexible(child: _body()),
          _inputBar(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: _orb,
          builder: (_, __) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(_orb.value * math.pi * 2),
                colors: const [
                  Color(0xFF7C4DFF),
                  Color(0xFF40C4FF),
                  Color(0xFF00E5FF),
                  Color(0xFF7C4DFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child:
            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ask AURA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text("Ask me about any subject! I'll do my best ✨",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded,
              color: Colors.white.withOpacity(0.4)),
          onPressed: widget.onClose,
        ),
      ],
    ),
  );

  // Priority ladder (top wins):
  //   1. streaming=true  + thinking=true  → spinner
  //   2. streaming=true  + thinking=false → drip text
  //   3. streaming=false + answer≠null    → committed bubble
  //   4. streaming=false + error≠null     → error state
  //   5. otherwise                        → suggestions
  Widget _body() {
    return ValueListenableBuilder<bool>(
      valueListenable: _streaming,
      builder: (_, isStreaming, __) {
        if (isStreaming) {
          return ValueListenableBuilder<bool>(
            valueListenable: _thinking,
            builder: (_, isThinking, __) {
              if (isThinking) return _thinkingWidget();
              return ValueListenableBuilder<String>(
                valueListenable: _streamText,
                builder: (_, txt, __) => SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: _answerBubble(txt),
                ),
              );
            },
          );
        }

        if (_answer != null) {
          return SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: _answerBubble(_answer!),
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _errorMsg,
          builder: (_, err, __) {
            if (err != null) return _errorWidget(err);
            return _suggestions();
          },
        );
      },
    );
  }

  Widget _suggestions() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kSuggestions
          .map((t) => GestureDetector(
        onTap: () {
          _ctrl.text = t;
          _send();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E32),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF7C4DFF).withOpacity(0.3)),
          ),
          child: Text(t,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13)),
        ),
      ))
          .toList(),
    ),
  );

  Widget _thinkingWidget() => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(),
        const SizedBox(width: 10),
        Text('AURA is thinking…',
            style: TextStyle(
                color: const Color(0xFF7C4DFF).withOpacity(0.7),
                fontSize: 13,
                fontStyle: FontStyle.italic)),
      ],
    ),
  );

  Widget _answerBubble(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(18),
      border:
      Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.2)),
    ),
    child: Text(text,
        style:
        const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
  );

  Widget _errorWidget(String msg) => GestureDetector(
    onTap: () => _errorMsg.value = null,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: Colors.redAccent.withOpacity(0.8),
                    fontSize: 13,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    ),
  );

  Widget _inputBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _hasText,
            builder: (_, ht, __) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E32),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: ht
                      ? const Color(0xFF7C4DFF).withOpacity(0.55)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style:
                const TextStyle(color: Colors.white, fontSize: 14),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Ask about any subject…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.22),
                      fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<bool>(
          valueListenable: _hasText,
          builder: (_, ht, __) => GestureDetector(
            onTap: (_busy || !ht) ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (ht && !_busy)
                    ? const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF40C4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: (!ht || _busy)
                    ? Colors.white.withOpacity(0.08)
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: (ht && !_busy)
                    ? Colors.white
                    : Colors.white.withOpacity(0.22),
                size: 19,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Animated dots ─────────────────────────────────────────────────────────────
class _Dots extends StatefulWidget {
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final p = ((_ac.value * 3) - i).clamp(0.0, 1.0);
        final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.25, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withOpacity(o),
            shape: BoxShape.circle,
          ),
        );
      }),
    ),
  );
}