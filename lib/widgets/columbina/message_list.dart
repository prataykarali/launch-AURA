part of '../columbina.dart';

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
          'say something to AURA',
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
