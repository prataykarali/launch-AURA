import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../class_data.dart';

const _kSentinel = '\x00__THINKING__\x00';

// ─────────────────────────────────────────────────────────────────────────────
// AiQuizTab — AI-generated MCQ quiz based on completed syllabus topics.
// • Calls auraChat() to generate 5 questions in a structured format
// • Parses the response into McqQuestion objects in Dart
// • Interactive quiz UI with instant feedback and XP reward
// ─────────────────────────────────────────────────────────────────────────────
class AiQuizTab extends StatefulWidget {
  final ClassData data;
  final List<dynamic> completedTopics; // Or your Topic model
  final int topicsDone;     // Added this
  final int topicsTotal;    // Added this
  final int studentCount;   // Added this
  final Function(int) onXpEarned;

  const AiQuizTab({
    super.key,
    required this.data,
    required this.completedTopics,
    required this.onXpEarned,
    this.topicsDone = 0,    // Default values to prevent errors
    this.topicsTotal = 0,
    this.studentCount = 0,
  });

  @override
  State<AiQuizTab> createState() => _AiQuizTabState();
}

class _AiQuizTabState extends State<AiQuizTab> {
  final _streamText = ValueNotifier<String>('');
  bool _loading = false;
  bool _done = false;
  bool _hasError = false;
  // ── State ──────────────────────────────────────────────────────────────────
  List<_McqQuestion> _questions  = [];
  bool               _generating = false;
  bool               _quizActive = false;
  String             _rawStream  = '';
  int                _current    = 0;
  int                _score      = 0;
  bool               _quizDone   = false;
  int?               _selectedAnswer;
  bool               _answered   = false;

  final _streamNotifier = ValueNotifier<String>('');

  // ── Generate quiz ──────────────────────────────────────────────────────────
  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading  = true;
      _done     = false;
      _hasError = false;
    });
    _streamText.value = '';

    final d   = widget.data;
    final pct = widget.topicsTotal == 0
        ? 0
        : (widget.topicsDone / widget.topicsTotal * 100).toInt();

    final prompt =
        'You are a helpful teacher for ${d.name} (${d.subject}). '
        'Write a brief daily class update as exactly 3 short bullet points. '
        'Each bullet starts with a relevant emoji and is under 12 words. '
        'Use this class info: syllabus $pct% done '
        '(${widget.topicsDone} topics completed), '
        '${widget.studentCount} students, '
        'teacher is ${d.teacher}. '
        'Write the 3 bullets now:';

    final buf = StringBuffer();
    try {
      await for (final token in auraChat(prompt: prompt)) {
        if (token == _kSentinel) continue;

        // Iterate through each character in the chunk for smooth typing
        for (var i = 0; i < token.length; i++) {
          buf.write(token[i]);
          _streamText.value = '${buf.toString()}▍';

          // Speed adjustment: 10ms per char feels natural for short briefings
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } catch (e) {
      debugPrint('SmartBriefingCard error: $e');
      setState(() => _hasError = true);
    }

    final finalText = buf.toString().trim();
    // Fallback if the stream fails or returns empty
    if (finalText.isEmpty && !_hasError) {
      _streamText.value = '• ${d.subject} class is on track.\n• ${widget.topicsDone} topics completed.\n• Keep up the great work!';
    } else {
      _streamText.value = finalText;
    }

    setState(() { _loading = false; _done = true; });
  }

  // ── Parse MCQ from raw LLM output ──────────────────────────────────────────
  List<_McqQuestion> _parseQuestions(String raw) {
    final questions = <_McqQuestion>[];
    // Split by Q: markers
    final blocks = raw.split(RegExp(r'Q\s*:\s*', caseSensitive: false));
    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final lines = block.split('\n')
          .map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) continue;

      final qText = lines[0];
      String? a, b, c, d, ans;

      for (final line in lines.skip(1)) {
        if (line.startsWith('A)') || line.startsWith('A.'))
          a = line.substring(2).trim();
        else if (line.startsWith('B)') || line.startsWith('B.'))
          b = line.substring(2).trim();
        else if (line.startsWith('C)') || line.startsWith('C.'))
          c = line.substring(2).trim();
        else if (line.startsWith('D)') || line.startsWith('D.'))
          d = line.substring(2).trim();
        else if (line.toUpperCase().startsWith('ANS:'))
          ans = line.substring(4).trim().toUpperCase();
      }

      if (a != null && b != null && c != null && d != null && ans != null) {
        final correctIdx = {'A': 0, 'B': 1, 'C': 2, 'D': 3}[ans] ?? 0;
        questions.add(_McqQuestion(
          question: qText,
          options:  [a, b, c, d],
          correct:  correctIdx,
        ));
      }
      if (questions.length == 5) break;
    }
    return questions;
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    final correct = _questions[_current].correct == idx;
    if (correct) _score++;
    setState(() { _selectedAnswer = idx; _answered = true; });
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _answered       = false;
        _selectedAnswer = null;
      });
    } else {
      // Quiz done
      final xp = _score * 20; // 20 XP per correct answer
      widget.onXpEarned(xp);
      HapticFeedback.heavyImpact();
      setState(() { _quizDone = true; });
    }
  }

  void _restart() => setState(() {
    _quizActive = false; _quizDone = false;
    _questions  = []; _current = 0; _score = 0;
  });

  @override
  void dispose() { _streamNotifier.dispose(); super.dispose(); }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    if (!_quizActive && !_generating) return _buildIntro(d);
    if (_generating)               return _buildGenerating(d);
    if (_quizDone)                 return _buildResults(d);
    return _buildQuestion(d);
  }

  // ── Intro screen ──────────────────────────────────────────────────────────
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

  // ── Generating screen ─────────────────────────────────────────────────────
  Widget _buildGenerating(ClassData d) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: d.accent, strokeWidth: 2),
        const SizedBox(height: 20),
        Text('AURA is writing your quiz…',
            style: TextStyle(color: Colors.white.withOpacity(0.6),
                fontSize: 14, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        // Live stream preview
        Container(
          height: 120,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161625),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: d.accent.withOpacity(0.2)),
          ),
          child: SingleChildScrollView(
            child: ValueListenableBuilder<String>(
              valueListenable: _streamNotifier,
              builder: (_, txt, __) => Text(txt,
                  style: TextStyle(color: Colors.white.withOpacity(0.4),
                      fontSize: 11, height: 1.4)),
            ),
          ),
        ),
      ]),
    ),
  );

  // ── Question screen ───────────────────────────────────────────────────────
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

  // ── Results screen ────────────────────────────────────────────────────────
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

class _McqQuestion {
  final String       question;
  final List<String> options;
  final int          correct;
  const _McqQuestion({required this.question, required this.options,
    required this.correct});
}