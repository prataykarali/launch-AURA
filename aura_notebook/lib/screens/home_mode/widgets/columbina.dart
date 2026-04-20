import 'dart:async';
import 'dart:collection';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Must match THINKING_SENTINEL in engine.rs exactly
const _kThinkingSentinel = '\x00__THINKING__\x00';

const _kSuggestions = [
  'Tell me a short story ✨',
  'Help me brainstorm 💡',
  'What can you do? 🎈',
];

// ── ROOT ──────────────────────────────────────────────────────────────────────
class AuraChatWidget extends StatefulWidget {
  const AuraChatWidget({super.key});
  @override
  State<AuraChatWidget> createState() => _AuraChatWidgetState();
}

class _AuraChatWidgetState extends State<AuraChatWidget> {

  final _messages   = <ChatMessage>[];
  final _streamText = ValueNotifier<String>('');
  final _streaming  = ValueNotifier<bool>(false);
  final _thinking   = ValueNotifier<bool>(false);
  final _scroll     = ScrollController();

  StreamSubscription<String>? _chatSub;
  bool _busy          = false;
  bool _jumpScheduled = false;

  // ── SEND ──────────────────────────────────────────────────────────────────

  // ── SEND ──────────────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    await WakelockPlus.enable();
    if (text.isEmpty || _busy) return;
    _busy = true;

    HapticFeedback.lightImpact();

    // 1. Instantly add user message and turn on thinking dots
    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _streamText.value = '';
    _streaming.value  = false;
    _thinking.value   = true;
    _scheduleJump();

    // 2. Tiny 10ms yield to guarantee Flutter draws the user bubble instantly
    await Future.delayed(const Duration(milliseconds: 10));

    final buf = StringBuffer();

    try {
      // 3. Connect to the Rust stream at MAX SPEED
      await for (final token in auraChat(prompt: text)) {
        if (token == _kThinkingSentinel) {
          continue;
        }

        if (_thinking.value) {
          _thinking.value  = false;
          _streaming.value = true;
        }

        // 4. Instantly append the character and update UI.
        // Flutter's ValueNotifier automatically batches screen draws at 60 FPS,
        // so this gives you the absolute lowest latency possible!
        buf.write(token);
        _streamText.value = '$buf▍';

        // This is safe because _scheduleJump already has an internal throttle
        _scheduleJump();
      }

    } catch (e) {
      debugPrint('stream error: $e');
    }

    // Commit final text as permanent bubble
    final finalText = buf.toString();
    _streamText.value = '';
    _streaming.value  = false;
    _thinking.value   = false;

    setState(() {
      _messages.add(ChatMessage(text: finalText, isUser: false));
    });

    _busy = false;
    await WakelockPlus.disable();
    _scheduleJump();
  }

  // ── SCROLL ────────────────────────────────────────────────────────────────
  void _scheduleJump() {
    if (_jumpScheduled || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels > 300) return;
    _jumpScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _jumpScheduled = false;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _streamText.dispose();
    _streaming.dispose();
    _thinking.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _MsgList(
          messages:     _messages,
          streamText:   _streamText,
          streaming:    _streaming,
          scroll:       _scroll,
          onSuggestion: _send,
        ),
      ),
      _Thinking(thinking: _thinking),
      _InputBar(onSend: _send, busy: _streaming),
    ],
  );
}

// ── DATA MODEL ────────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool   isUser;
  const ChatMessage({required this.text, required this.isUser});
}

// ── MESSAGE LIST ──────────────────────────────────────────────────────────────
class _MsgList extends StatelessWidget {
  final List<ChatMessage>             messages;
  final ValueNotifier<String>         streamText;
  final ValueNotifier<bool>           streaming;
  final ScrollController              scroll;
  final Future<void> Function(String) onSuggestion;

  const _MsgList({
    required this.messages,
    required this.streamText,
    required this.streaming,
    required this.scroll,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: streaming,
      builder: (context, isStreaming, _) {
        if (messages.isEmpty && !isStreaming) {
          return _EmptyState(onSuggestion: onSuggestion);
        }
        return CustomScrollView(
          controller: scroll,
          cacheExtent: 3000,
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Committed messages — never rebuild during streaming
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList.builder(
                itemCount: messages.length,
                itemBuilder: (_, i) => _Bubble(
                  key:    ValueKey('m$i'),
                  text:   messages[i].text,
                  isUser: messages[i].isUser,
                ),
              ),
            ),
            // Live streaming bubble — RepaintBoundary isolates repaints
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: isStreaming
                    ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<String>(
                      valueListenable: streamText,
                      builder: (_, txt, __) => _Bubble(
                        key:    const ValueKey('live'),
                        text:   txt,
                        isUser: false,
                      ),
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        );
      },
    );
  }
}

// ── EMPTY STATE ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Future<void> Function(String) onSuggestion;
  const _EmptyState({required this.onSuggestion});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'say something to AURA ✨',
          style: TextStyle(
            color: Colors.indigo.shade200,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _kSuggestions.map((s) => ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 13)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.indigo.shade100),
            onPressed: () => onSuggestion(s),
          )).toList(),
        ),
      ],
    ),
  );
}

// ── THINKING DOTS ─────────────────────────────────────────────────────────────
class _Thinking extends StatelessWidget {
  final ValueNotifier<bool> thinking;
  const _Thinking({required this.thinking});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: thinking,
    builder: (_, on, __) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: on
          ? Padding(
        key: const ValueKey('on'),
        padding: const EdgeInsets.only(left: 24, bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(),
              const SizedBox(width: 8),
              Text(
                'AURA is thinking…',
                style: TextStyle(
                  color:     Colors.indigo.shade300,
                  fontSize:  12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      )
          : const SizedBox.shrink(key: ValueKey('off')),
    ),
  );
}

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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final p = ((_ac.value * 3) - i).clamp(0.0, 1.0);
        final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4, height: 4,
          decoration: BoxDecoration(
            color: Colors.indigo.shade300.withOpacity(o),
            shape: BoxShape.circle,
          ),
        );
      }),
    ),
  );
}

// ── INPUT BAR ─────────────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final ValueNotifier<bool>           busy;
  const _InputBar({required this.onSend, required this.busy});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool  _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    _focus.requestFocus();
    widget.onSend(t);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.busy,
    builder: (_, isBusy, __) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(
            color:      Colors.indigo.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller:        _ctrl,
                focusNode:         _focus,
                onSubmitted:       (_) => isBusy ? null : _submit(),
                textInputAction:   TextInputAction.send,
                enableSuggestions: false,
                autocorrect:       false,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  hintText:       'Talk to AURA...',
                  hintStyle:      TextStyle(color: Colors.black38, fontSize: 15),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: isBusy ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_hasText && !isBusy)
                        ? Colors.indigoAccent
                        : Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: (_hasText && !isBusy)
                        ? Colors.white
                        : Colors.indigo.shade300,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── BUBBLE ────────────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final String text;
  final bool   isUser;
  const _Bubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigoAccent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(20),
            topRight:    const Radius.circular(20),
            bottomLeft:  Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          )],
        ),
        child: Text(
          text,
          style: TextStyle(
            color:    isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height:   1.45,
          ),
        ),
      ),
    ),
  );
}