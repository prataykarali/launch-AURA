// message_list.dart
// Scrollable message list + live streaming bubble + empty state + thinking dots.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'chat_constants.dart';
import 'chat_message.dart';

// ─── Message list ─────────────────────────────────────────────────────────────

class MsgList extends StatelessWidget {
  final List<ChatMessage>         messages;
  final ValueNotifier<String>     streamText;
  final ValueNotifier<bool>       streaming;
  final ScrollController          scroll;
  final Future<void> Function(String) onSuggestion;

  const MsgList({
    super.key,
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
                itemBuilder: (_, i) => ChatBubble(
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
                          builder: (_, txt, __) => ChatBubble(
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
          children: kSuggestions
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

class ThinkingIndicator extends StatelessWidget {
  final ValueNotifier<bool> thinking;
  const ThinkingIndicator({super.key, required this.thinking});

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
                    _ThinkingDots(),
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

class _ThinkingDots extends StatefulWidget {
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
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

// ─── Bubble ───────────────────────────────────────────────────────────────────

class ChatBubble extends StatelessWidget {
  final String text;
  final bool   isUser;
  const ChatBubble({super.key, required this.text, required this.isUser});

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