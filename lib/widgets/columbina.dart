import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'columbina/message_list.dart';
part 'columbina/input_section.dart';

const _kThinkingSentinel = '\x00__THINKING__\x00';

const _kSuggestions = [
  'Tell me a short story',
  'Help me brainstorm',
  'What can you do?',
];

// ── DATA MODEL ────────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool   isUser;
  const ChatMessage({required this.text, required this.isUser});
}

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

  Future<void> _send(String text) async {
    await WakelockPlus.enable();
    if (text.isEmpty || _busy) return;
    _busy = true;

    HapticFeedback.lightImpact();

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _streamText.value = '';
    _streaming.value  = false;
    _thinking.value   = true;
    _scheduleJump();

    await Future.delayed(const Duration(milliseconds: 10));

    final buf = StringBuffer();

    try {
      await for (final token in auraChat(prompt: text)) {
        if (token == _kThinkingSentinel) continue;

        if (_thinking.value) {
          _thinking.value  = false;
          _streaming.value = true;
        }

        buf.write(token);
        _streamText.value = '$buf\u258D';
        _scheduleJump();
      }
    } catch (e) {
      debugPrint('stream error: $e');
    }

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
