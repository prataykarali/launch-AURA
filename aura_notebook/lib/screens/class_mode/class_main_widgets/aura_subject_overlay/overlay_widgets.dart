part of 'package:aura_notebook/screens/class_mode/class_main_widgets/aura_subject_overlay.dart';

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 38, height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final AnimationController orb;
  final VoidCallback onClose;
  const _Header({required this.orb, required this.onClose});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
    child: Row(
      children: [
        // Spinning orb
        AnimatedBuilder(
          animation: orb,
          builder: (_, __) => Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(orb.value * math.pi * 2),
                colors: const [
                  Color(0xFF7C4DFF), Color(0xFF40C4FF),
                  Color(0xFF00E5FF), Color(0xFF7C4DFF),
                ],
              ),
              boxShadow: [BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.5),
                blurRadius: 14,
              )],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ask AURA',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text('Ask me about any subject! I\'ll do my best ✨',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded,
              color: Colors.white.withOpacity(0.4)),
          onPressed: onClose,
        ),
      ],
    ),
  );
}

class _Suggestions extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  const _Suggestions({required this.suggestions, required this.onSelected});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: suggestions.map((t) => GestureDetector(
        onTap: () { onSelected(t); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E32),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF7C4DFF).withOpacity(0.3)),
          ),
          child: Text(t,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ),
      )).toList(),
    ),
  );
}

class _ThinkingWidget extends StatelessWidget {
  const _ThinkingWidget();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dots(),
        const SizedBox(width: 10),
        Text('AURA is thinking…',
            style: TextStyle(
                color: const Color(0xFF7C4DFF).withOpacity(0.7),
                fontSize: 13, fontStyle: FontStyle.italic)),
      ],
    ),
  );
}

class _AnswerBubble extends StatelessWidget {
  final String text;
  const _AnswerBubble({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
          color: const Color(0xFF7C4DFF).withOpacity(0.2)),
    ),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, height: 1.6)),
  );
}

// ── Input bar — send always visible ────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool busy;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Row(
      children: [
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E32),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: hasText
                    ? const Color(0xFF7C4DFF).withOpacity(0.55)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: TextField(
              controller: controller, focusNode: focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Ask about any subject…',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.22), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send button — always visible, separate from text field
        GestureDetector(
          onTap: busy ? null : onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: (hasText && !busy)
                  ? const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF40C4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: (!hasText || busy)
                  ? Colors.white.withOpacity(0.08)
                  : null,
            ),
            child: Icon(
              Icons.send_rounded,
              color: (hasText && !busy)
                  ? Colors.white
                  : Colors.white.withOpacity(0.22),
              size: 19,
            ),
          ),
        ),
      ],
    ),
  );
}
