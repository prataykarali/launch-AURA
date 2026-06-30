part of 'ai_quiz_tab.dart';

const _kSentinel = '\x00__THINKING__\x00';

class _McqQuestion {
  final String       question;
  final List<String> options;
  final int          correct;
  const _McqQuestion({required this.question, required this.options,
    required this.correct});
}
