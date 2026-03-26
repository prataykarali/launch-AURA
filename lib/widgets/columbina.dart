import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aura_notebook/src/rust/api.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT — never rebuilds
// ═══════════════════════════════════════════════════════════════════════════════
class AuraChatWidget extends StatefulWidget {
  const AuraChatWidget({super.key});
  @override
  State<AuraChatWidget> createState() => _AuraChatWidgetState();
}

class _AuraChatWidgetState extends State<AuraChatWidget>
    with SingleTickerProviderStateMixin {

  final _messages   = <ChatMessage>[];
  final _streamText = ValueNotifier<String>('');
  final _streaming  = ValueNotifier<bool>(false);
  final _loading    = ValueNotifier<bool>(false);
  final _scroll     = ScrollController();
  final _charQueue  = Queue<String>();
  final _rendered   = StringBuffer();

  late final Ticker _ticker;
  bool _busy        = false;
  bool _streamDone  = false;
  bool _jumpPending = false;

  static const _cpf = 5;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration _) {
    if (_charQueue.isEmpty) {
      if (_streamDone) { _ticker.stop(); _commitBubble(); }
      return;
    }
    int n = _cpf;
    while (_charQueue.isNotEmpty && n-- > 0) {
      _rendered.write(_charQueue.removeFirst());
    }
    _streamText.value = _rendered.toString();
    _scheduleJump();
  }

  Future<void> _send(String text) async {
    if (text.isEmpty || _busy) return;
    _busy = true; _streamDone = false;
    _charQueue.clear(); _rendered.clear();

    _messages.add(ChatMessage(text: text, isUser: true));
    _streamText.value = ''; _loading.value = true; _streaming.value = true;
    _scheduleJump();

    await for (final token in auraChat(prompt: text)) {
      for (final ch in token.characters) _charQueue.add(ch);
      if (!_ticker.isActive) _ticker.start();
    }
    _streamDone = true; _loading.value = false;
    if (!_ticker.isActive) {
      if (_charQueue.isNotEmpty) _ticker.start();
      else _commitBubble();
    }
  }

  void _commitBubble() {
    if (!_busy) return;
    _messages.add(ChatMessage(text: _rendered.toString(), isUser: false));
    _streamText.value = ''; _streaming.value = false; _busy = false;
    _scheduleJump();
  }

  void _scheduleJump() {
    if (_jumpPending) return;
    _jumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpPending = false;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _ticker.dispose(); _streamText.dispose(); _streaming.dispose();
    _loading.dispose(); _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: _MsgList(
        messages: _messages, streamText: _streamText,
        streaming: _streaming, scroll: _scroll,
      )),
      _Thinking(loading: _loading),
      _InputBar(onSend: _send),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE LIST
// ═══════════════════════════════════════════════════════════════════════════════
class _MsgList extends StatefulWidget {
  final List<ChatMessage>     messages;
  final ValueNotifier<String> streamText;
  final ValueNotifier<bool>   streaming;
  final ScrollController      scroll;
  const _MsgList({
    required this.messages, required this.streamText,
    required this.streaming, required this.scroll,
  });
  @override State<_MsgList> createState() => _MsgListState();
}

class _MsgListState extends State<_MsgList> {
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    widget.streaming.addListener(_flip);
  }

  void _flip() {
    if (mounted) setState(() => _isStreaming = widget.streaming.value);
  }

  @override
  void dispose() { widget.streaming.removeListener(_flip); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty && !_isStreaming) {
      return Center(child: Text('say something to AURA ✨',
          style: TextStyle(color: Colors.indigo.shade200,
              fontSize: 14, fontStyle: FontStyle.italic)));
    }
    return ListView.builder(
      controller: widget.scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: widget.messages.length + (_isStreaming ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isStreaming && i == widget.messages.length) {
          return RepaintBoundary(
            child: ValueListenableBuilder<String>(
              valueListenable: widget.streamText,
              builder: (_, txt, __) => _Bubble(text: txt, isUser: false),
            ),
          );
        }
        return _Bubble(
            text: widget.messages[i].text,
            isUser: widget.messages[i].isUser);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// THINKING DOTS
// ═══════════════════════════════════════════════════════════════════════════════
class _Thinking extends StatelessWidget {
  final ValueNotifier<bool> loading;
  const _Thinking({required this.loading});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: loading,
    builder: (_, on, __) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: on
          ? Padding(
          key: const ValueKey('t'),
          padding: const EdgeInsets.only(left: 24, bottom: 6),
          child: Align(alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _Dots(),
                const SizedBox(width: 8),
                Text('AURA is thinking…', style: TextStyle(
                    color: Colors.indigo.shade300, fontSize: 12,
                    fontStyle: FontStyle.italic)),
              ])))
          : const SizedBox.shrink(key: ValueKey('e')),
    ),
  );
}

class _Dots extends StatefulWidget {
  @override State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))..repeat();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final p = ((_ac.value * 3) - i).clamp(0.0, 1.0);
          final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.3, 1.0);
          return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 4, height: 4,
              decoration: BoxDecoration(
                  color: Colors.indigo.shade300.withOpacity(o),
                  shape: BoxShape.circle));
        })),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// INPUT BAR — isolated subtree, keyboard never touches parent
// ═══════════════════════════════════════════════════════════════════════════════
class _InputBar extends StatefulWidget {
  final Future<void> Function(String) onSend;
  const _InputBar({required this.onSend});
  @override State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

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

  @override void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.send,
          enableSuggestions: false,
          autocorrect: false,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: const InputDecoration(
            hintText: 'Talk to AURA...',
            hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
            border: InputBorder.none,
            contentPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        )),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _hasText ? Colors.indigoAccent : Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.send_rounded,
                  color: _hasText ? Colors.white : Colors.indigo.shade300,
                  size: 18),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUBBLE
// ═══════════════════════════════════════════════════════════════════════════════
class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _Bubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigoAccent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(20),
            topRight:    const Radius.circular(20),
            bottomLeft:  Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Text(text, style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15, height: 1.45)),
      ),
    ),
  );
}