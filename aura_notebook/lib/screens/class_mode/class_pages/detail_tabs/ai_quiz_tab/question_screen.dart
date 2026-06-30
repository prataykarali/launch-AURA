part of 'ai_quiz_tab.dart';

// ── Question screen ───────────────────────────────────────────────────────
extension _AiQuizTabStateQuestion on _AiQuizTabState {
  Widget _buildQuestion(ClassData d) {
    final q   = _questions[_current];
    final pct = (_current + 1) / _questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Progress header
        Row(children: [
          Text('Question ${_current + 1} of ${_questions.length}',
              style: TextStyle(color: Colors.white.withOpacity(0.45),
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Score: $_score',
              style: TextStyle(color: d.accent, fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(d.accent),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 24),

        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161625),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: d.accent.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: d.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Q${_current + 1}',
                    style: TextStyle(color: d.accent, fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: const Color(0xFF7C4DFF).withOpacity(0.6)),
              const SizedBox(width: 4),
              Text('AI Generated',
                  style: TextStyle(color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
            ]),
            const SizedBox(height: 14),
            Text(q.question,
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w600, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 16),

        // Options
        ...q.options.asMap().entries.map((e) {
          final idx = e.key;
          final opt = e.value;
          final label = ['A', 'B', 'C', 'D'][idx];
          Color? bg; Color textCol = Colors.white;

          if (_answered) {
            if (idx == q.correct) {
              bg = Colors.greenAccent.withOpacity(0.15);
              textCol = Colors.greenAccent;
            } else if (idx == _selectedAnswer && idx != q.correct) {
              bg = Colors.redAccent.withOpacity(0.15);
              textCol = Colors.redAccent;
            }
          } else if (idx == _selectedAnswer) {
            bg = d.color.withOpacity(0.2);
          }

          return GestureDetector(
            onTap: () => _selectAnswer(idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg ?? const Color(0xFF161625),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _answered && idx == q.correct
                      ? Colors.greenAccent.withOpacity(0.5)
                      : _answered && idx == _selectedAnswer
                      ? Colors.redAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                  width: (_answered && (idx == q.correct ||
                      idx == _selectedAnswer)) ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _answered && idx == q.correct
                        ? Colors.greenAccent.withOpacity(0.2)
                        : _answered && idx == _selectedAnswer
                        ? Colors.redAccent.withOpacity(0.2)
                        : d.color.withOpacity(0.15),
                  ),
                  child: Center(child: Text(label,
                      style: TextStyle(color: textCol, fontSize: 12,
                          fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(opt,
                    style: TextStyle(color: textCol.withOpacity(
                        _answered && idx != q.correct && idx != _selectedAnswer
                            ? 0.4 : 1.0),
                        fontSize: 13, fontWeight: FontWeight.w500))),
                if (_answered && idx == q.correct)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent, size: 18),
                if (_answered && idx == _selectedAnswer && idx != q.correct)
                  const Icon(Icons.cancel_rounded,
                      color: Colors.redAccent, size: 18),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),
        if (_answered)
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                  backgroundColor: d.color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text(
                  _current < _questions.length - 1 ? 'Next Question →' : 'See Results',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
      ]),
    );
  }
}
