class TranslationResult {
  const TranslationResult({
    required this.original,
    required this.english,
    required this.changed,
    required this.source,
  });

  final String original;
  final String english;
  final bool changed;
  final String source;
}
