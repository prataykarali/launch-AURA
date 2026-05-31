import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../notebook_page.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kThinkingSentinel = '\x00__THINKING__\x00';

const _kSuggestions = [
  'Tell me a short story ✨',
  'Help me brainstorm 💡',
  'What can you do? 🎈',
  'Show my notebook 📓',
];

/// Messages shorter than this char count go as a single turn.
/// Longer ones get chunked.
const _kChunkThreshold = 150;

/// Debounce delay before firing keystroke prefill to Rust.
const _kPrefillDebounce = Duration(milliseconds: 300);

// ─── Message chunker ──────────────────────────────────────────────────────────

/// Splits a long user message into sequential chunks:
/// 1. Split on paragraph boundaries (\n\n) first
/// 2. Then split any remaining long segment on sentence boundaries (.!?)
/// 3. Then hard-cap at ~80 "words" (~400 chars) as final fallback
List<String> _chunkMessage(String text) {
  // Step 1 — paragraph split
  final paragraphs = text
      .split(RegExp(r'\n\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  final chunks = <String>[];

  for (final para in paragraphs) {
    if (para.length <= _kChunkThreshold) {
      chunks.add(para);
      continue;
    }

    // Step 2 — sentence split within long paragraph
    // Split after .!? followed by space or end
    final sentences = para.split(RegExp(r'(?<=[.!?])\s+'));
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      final candidate = buffer.isEmpty
          ? sentence
          : '${buffer.toString()} $sentence';

      if (candidate.length > _kChunkThreshold && buffer.isNotEmpty) {
        // Flush current buffer as a chunk
        chunks.add(buffer.toString().trim());
        buffer = StringBuffer(sentence);
      } else {
        buffer.clear();
        buffer.write(candidate);
      }
    }

    if (buffer.isNotEmpty) {
      final remaining = buffer.toString().trim();
      // Step 3 — hard cap fallback: split on word boundary at ~400 chars
      if (remaining.length > 400) {
        var start = 0;
        while (start < remaining.length) {
          var end = (start + 400).clamp(0, remaining.length);
          // Walk back to nearest space
          if (end < remaining.length) {
            final spaceIdx = remaining.lastIndexOf(' ', end);
            if (spaceIdx > start) end = spaceIdx;
          }
          chunks.add(remaining.substring(start, end).trim());
          start = end;
        }
      } else {
        chunks.add(remaining);
      }
    }
  }

  return chunks.isEmpty ? [text.trim()] : chunks;
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class AuraChatWidget extends StatefulWidget {
  const AuraChatWidget({super.key});

  @override
  State<AuraChatWidget> createState() => _AuraChatWidgetState();
}

class _AuraChatWidgetState extends State<AuraChatWidget> {
  final _messages    = <ChatMessage>[];
  final _streamText  = ValueNotifier<String>('');
  final _streaming   = ValueNotifier<bool>(false);
  final _thinking    = ValueNotifier<bool>(false);
  final _busyNotifier = ValueNotifier<bool>(false);
  final _scroll      = ScrollController();

  StreamSubscription<String>? _chatSub;
  bool _busy = false;
  bool _jumpScheduled = false;

  // Prefill debounce
  Timer?  _prefillTimer;
  String  _lastPrefilled = '';

  // ── Keystroke prefill ────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    _prefillTimer?.cancel();

    final trimmed = text.trim();
    if (trimmed.length < 4 || trimmed == _lastPrefilled) return;

    _prefillTimer = Timer(_kPrefillDebounce, () {
      if (!_busy && trimmed.length >= 4) {
        _lastPrefilled = trimmed;
        // Fire prefill to Rust — fire-and-forget, no await
        auraPrefill(partial: trimmed);
        debugPrint('PREFILL_FIRED: ${trimmed.length} chars');
      }
    });
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    if (text.isEmpty || _busy) return;

    // Cancel pending prefill debounce — we're sending now
    _prefillTimer?.cancel();

    // Notebook shortcut
    if (text.toLowerCase().contains('notebook')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NotebookPage()),
      );
      return;
    }

    _busy = true;
    _busyNotifier.value = true;
    HapticFeedback.lightImpact();
    await WakelockPlus.enable();

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _streamText.value = '';
    _streaming.value  = false;
    _thinking.value   = true;
    _scheduleJump();

    await Future.delayed(const Duration(milliseconds: 10));

    final buf       = StringBuffer();
    bool committed  = false;

    void commit(String t) {
      if (committed) return;
      committed = true;
      _commitBubble(t);
    }

    // 120s safety release — in case onDone never fires
    Future.delayed(const Duration(seconds: 120), () {
      if (_busy && mounted) {
        debugPrint('FORCE_UNLOCK: releasing stuck busy flag');
        commit(buf.isNotEmpty ? buf.toString() : '⚠️ No response.');
      }
    });

    // ── Decide: single turn or chunked ───────────────────────────────────
    final Stream<String> stream;

    if (text.length > _kChunkThreshold) {
      final chunks = _chunkMessage(text);
      debugPrint('CHUNKED: ${chunks.length} chunks from ${text.length} chars');
      for (var i = 0; i < chunks.length; i++) {
        debugPrint('  chunk $i: ${chunks[i].substring(0, chunks[i].length.clamp(0, 60))}…');
      }
      stream = auraChatChunked(chunks: chunks);
    } else {
      stream = auraChat(prompt: text);
    }

    // ── Subscribe ────────────────────────────────────────────────────────
    try {
      _chatSub = stream.listen(
        (token) {
          if (token == _kThinkingSentinel) return;

          if (_thinking.value) {
            _thinking.value  = false;
            _streaming.value = true;
          }

          buf.write(token);
          _streamText.value = '$buf▍';
          _scheduleJump();
        },
        onError: (Object err) {
          debugPrint('stream error: $err');
          commit(buf.isNotEmpty ? buf.toString() : '⚠️ Something went wrong.');
        },
        onDone: () {
          debugPrint('STREAM_DONE: ${buf.length} chars');
          commit(buf.toString());
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('send error: $e');
      commit(buf.isNotEmpty ? buf.toString() : '⚠️ Engine error.');
    }
  }

  // ── Commit bubble ─────────────────────────────────────────────────────────

  void _commitBubble(String text) {
    _busy            = false;
    _busyNotifier.value = false;
    _lastPrefilled   = '';  // reset so next typing starts fresh prefill

    if (!mounted) {
      WakelockPlus.disable();
      return;
    }

    _streamText.value = '';
    _streaming.value  = false;
    _thinking.value   = false;

    if (text.isNotEmpty) {
      setState(() => _messages.add(ChatMessage(text: text, isUser: false)));
    }

    WakelockPlus.disable();
    _scheduleJump();
  }

  void _scheduleJump() {
    if (_jumpScheduled || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels > 600) return;
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
    _prefillTimer?.cancel();
    _chatSub?.cancel();
    _streamText.dispose();
    _streaming.dispose();
    _thinking.dispose();
    _busyNotifier.dispose();
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
      _InputBar(
        onSend:      _send,
        busy:        _busyNotifier,
        onChanged:   _onTextChanged,   // ← keystroke prefill hook
      ),
    ],
  );
}

// ─── Data model ───────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

// ─── Message list ─────────────────────────────────────────────────────────────

class _MsgList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ValueNotifier<String> streamText;
  final ValueNotifier<bool> streaming;
  final ScrollController scroll;
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList.builder(
                itemCount: messages.length,
                itemBuilder: (_, i) => _Bubble(
                  key: ValueKey('m$i'),
                  text: messages[i].text,
                  isUser: messages[i].isUser,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: isStreaming
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ValueListenableBuilder<String>(
                          valueListenable: streamText,
                          builder: (_, txt, __) => _Bubble(
                            key: const ValueKey('live'),
                            text: txt,
                            isUser: false,
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

// ─── Empty state ──────────────────────────────────────────────────────────────

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
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _kSuggestions
              .map(
                (s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 13)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.indigo.shade100),
                  onPressed: () => onSuggestion(s),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

// ─── Thinking indicator ───────────────────────────────────────────────────────

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
                        color: Colors.indigo.shade300,
                        fontSize: 12,
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
        final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.indigo.shade300.withOpacity(o),
            shape: BoxShape.circle,
          ),
        );
      }),
    ),
  );
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final ValueNotifier<bool> busy;
  final void Function(String) onChanged;   // keystroke prefill hook

  const _InputBar({
    required this.onSend,
    required this.busy,
    required this.onChanged,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.trim().isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
      // Fire prefill hook on every change
      widget.onChanged(_ctrl.text);
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
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.busy,
    builder: (_, isBusy, __) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode:  _focus,
                enabled:    !isBusy,
                onSubmitted: (_) => isBusy ? null : _submit(),
                textInputAction: TextInputAction.send,
                enableSuggestions: false,
                autocorrect:       false,
                maxLines: null,         // allow multi-line input naturally
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Talk to AURA...',
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: (!isBusy && _hasText) ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
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

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    ),
  );
}