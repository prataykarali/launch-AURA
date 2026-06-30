part of 'ai_quiz_tab.dart';

class _AiQuizTabState extends State<AiQuizTab> {
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

  Timer? _typewriterTimer;
  final List<String> _typewriterQueue = [];
  final StringBuffer _displayedBuffer = StringBuffer();
  bool _generationFinished = false;

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_typewriterQueue.isNotEmpty) {
        int charsToPop = 1;
        if (_typewriterQueue.length > 80) {
          charsToPop = 4;
        } else if (_typewriterQueue.length > 40) {
          charsToPop = 3;
        } else if (_typewriterQueue.length > 15) {
          charsToPop = 2;
        }

        for (int i = 0; i < charsToPop && _typewriterQueue.isNotEmpty; i++) {
          _displayedBuffer.write(_typewriterQueue.removeAt(0));
        }

        _streamNotifier.value = '$_displayedBuffer▍';
      } else if (_generationFinished) {
        timer.cancel();
        _streamNotifier.value = _displayedBuffer.toString();
        _finalizeQuiz();
      }
    });
  }

  void _finalizeQuiz() {
    final finalText = _displayedBuffer.toString().trim();
    final questions = _parseQuestions(finalText);
    if (questions.isNotEmpty) {
      setState(() {
        _questions = questions;
        _quizActive = true;
        _generating = false;
      });
    } else {
      setState(() {
        _generating = false;
        _quizActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate quiz. Please try again.')),
      );
    }
  }

  // ── Generate quiz ──────────────────────────────────────────────────────────
  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _quizActive = false;
      _quizDone = false;
      _questions = [];
      _current = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
    });
    _streamNotifier.value = '';
    _displayedBuffer.clear();
    _typewriterQueue.clear();
    _generationFinished = false;
    _startTypewriter();

    final d = widget.data;
    final topicsList = widget.completedTopics.isNotEmpty
        ? widget.completedTopics.map((t) => t.toString()).join(', ')
        : 'general ${d.subject} concepts';

    final prompt =
        'You are a teacher for ${d.name} (${d.subject}). '
        'Generate an interactive multiple-choice quiz with exactly 5 questions based on these completed topics: $topicsList. '
        'Format each question EXACTLY like this structure:\n'
        'Q: [Question text]\n'
        'A) [Option A text]\n'
        'B) [Option B text]\n'
        'C) [Option C text]\n'
        'D) [Option D text]\n'
        'ANS: [A, B, C, or D]\n\n'
        'Do not add any other conversational text or markdown around the questions. Just output the 5 formatted questions.';

    try {
      await for (final token in auraChat(prompt: prompt)) {
        if (!mounted) return;
        if (token == _kSentinel) continue;

        for (final rune in token.runes) {
          _typewriterQueue.add(String.fromCharCode(rune));
        }
      }
    } catch (e) {
      debugPrint('AiQuizTab generation error: $e');
      _generationFinished = true;
    }

    _generationFinished = true;
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
  void dispose() {
    _typewriterTimer?.cancel();
    _streamNotifier.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    if (!_quizActive && !_generating) return _buildIntro(d);
    if (_generating)               return _buildGenerating(d);
    if (_quizDone)                 return _buildResults(d);
    return _buildQuestion(d);
  }
}
