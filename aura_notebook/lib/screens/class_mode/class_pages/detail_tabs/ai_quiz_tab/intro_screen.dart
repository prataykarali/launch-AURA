part of 'ai_quiz_tab.dart';

// ── Intro screen ──────────────────────────────────────────────────────────
extension _AiQuizTabStateIntro on _AiQuizTabState {
  Widget _buildIntro(ClassData d) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [d.accent.withOpacity(0.8), d.color.withOpacity(0.3)]),
            boxShadow: [BoxShadow(
                color: d.accent.withOpacity(0.35), blurRadius: 20)],
          ),
          child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text('AI Practice Quiz',
            style: TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          widget.completedTopics.isEmpty
              ? 'Complete some topics first to generate a tailored quiz.'
              : 'AURA will generate 5 questions based on your\n${widget.completedTopics.length} completed topics.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.45),
              fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 6),
        Text('Earn up to 100 XP',
            style: TextStyle(color: d.accent, fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 28),
        if (widget.completedTopics.isNotEmpty)
          GestureDetector(
            onTap: _generate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [d.color, d.accent],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(
                    color: d.color.withOpacity(0.4), blurRadius: 16)],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Generate Quiz', style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
      ]),
    ),
  );
}
