part of 'ai_quiz_tab.dart';

// ── Results screen ────────────────────────────────────────────────────────
extension _AiQuizTabStateResults on _AiQuizTabState {
  Widget _buildResults(ClassData d) {
    final xp  = _score * 20;
    final pct = _score / _questions.length;
    final msg = pct == 1.0 ? 'Perfect Score! 🎉'
        : pct >= 0.8 ? 'Excellent! 🌟'
        : pct >= 0.6 ? 'Good effort! 👍'
        : 'Keep practising! 💪';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          // Score circle
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                d.accent.withOpacity(0.8), d.color.withOpacity(0.2)]),
              boxShadow: [BoxShadow(
                  color: d.accent.withOpacity(0.4), blurRadius: 24)],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_score/${_questions.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900)),
              Text('correct', style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 20),
          // XP earned
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: d.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: d.accent.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded, color: d.accent, size: 18),
              const SizedBox(width: 6),
              Text('+$xp XP earned!',
                  style: TextStyle(color: d.accent, fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _restart,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Try Again',
                  style: TextStyle(color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: d.color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('New Quiz',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      ),
    );
  }
}
