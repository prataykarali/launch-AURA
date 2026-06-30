part of 'service.dart';

enum AuraObservationSource { vision, speech, text }

class AuraObservation {
  AuraObservation({
    required this.source,
    required this.original,
    required this.english,
    required this.summary,
    required this.translationSource,
    required this.timestamp,
    Map<String, Object?>? metadata,
  }) : metadata = metadata ?? const {};

  final AuraObservationSource source;
  final String original;
  final String english;
  final String summary;
  final String translationSource;
  final DateTime timestamp;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'source': source.name,
    'original': original,
    'english': english,
    'summary': summary,
    'translation_source': translationSource,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

class NormalizedUserInput {
  const NormalizedUserInput({
    required this.original,
    required this.english,
    required this.translationSource,
  });

  final String original;
  final String english;
  final String translationSource;
}
