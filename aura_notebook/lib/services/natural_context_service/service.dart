import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../translation_service.dart';

part 'models.dart';
part 'summarization.dart';

class NaturalContextService {
  NaturalContextService._();
  static final NaturalContextService instance = NaturalContextService._();

  static const int _maxRecent = 8;
  static const Duration _globalCooldown = Duration(minutes: 2);
  static const Duration _sourceCooldown = Duration(minutes: 4);
  static const Duration _duplicateWindow = Duration(minutes: 12);
  static const Duration _sustainedWindow = Duration(minutes: 6);
  static const int _sustainedMinObservations = 3;

  Future<void> Function(String payload)? onNaturalTrigger;

  final List<AuraObservation> _recent = <AuraObservation>[];
  final Map<AuraObservationSource, DateTime> _lastTriggerBySource = {};
  final Map<String, DateTime> _firstSeenBySignal = {};
  final Map<String, int> _seenCountBySignal = {};
  DateTime? _lastTriggerAt;
  String? _lastSignature;

  List<AuraObservation> get recent => List.unmodifiable(_recent);

  Future<NormalizedUserInput> normalizeUserInput(
    String text, {
    required AuraObservationSource source,
    bool proactiveCandidate = false,
  }) async {
    final translated = await TranslationService.instance.toEnglish(text);
    final observation = AuraObservation(
      source: source,
      original: translated.original.trim(),
      english: translated.english.trim(),
      summary: _summarizeUserText(translated.english),
      translationSource: translated.source,
      timestamp: DateTime.now(),
      metadata: {'changed': translated.changed},
    );
    _remember(observation);

    final speechSignal = source == AuraObservationSource.speech
        ? _speechProactiveSummary(translated.english)
        : null;
    if (speechSignal != null) {
      await _maybeTrigger(observation, sustainedSummary: speechSignal);
    }

    return NormalizedUserInput(
      original: translated.original,
      english: translated.english,
      translationSource: translated.source,
    );
  }

  Future<void> observeVision({
    required List<String> labels,
    required double confidence,
    String? activeWindow,
  }) async {
    final normalizedLabels =
        labels
            .map((label) => label.trim())
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (normalizedLabels.isEmpty) return;

    final interesting = _interestingLabels(normalizedLabels);
    final summary = _summarizeVision(
      labels: normalizedLabels,
      interestingLabels: interesting,
      activeWindow: activeWindow,
    );
    final observation = AuraObservation(
      source: AuraObservationSource.vision,
      original: summary,
      english: summary,
      summary: summary,
      translationSource: 'vision_labels',
      timestamp: DateTime.now(),
      metadata: {
        'labels': normalizedLabels,
        'interesting_labels': interesting,
        'confidence': confidence,
        if (activeWindow != null && activeWindow.trim().isNotEmpty)
          'active_window': activeWindow.trim(),
      },
    );
    _remember(observation);

    if (interesting.isEmpty || confidence < 0.55) {
      return;
    }
    final immediate = interesting.any(
      (label) =>
          label.contains('wave') ||
          label.contains('gesture') ||
          label.contains('hand_pose') ||
          label.contains('open_palm') ||
          label.contains('thumbs_up') ||
          label.contains('expression') ||
          label.contains('smiling'),
    );
    final sustained = immediate
        ? 'The user appears to be greeting or gesturing. If useful, respond naturally in English.'
        : _sustainedSummary(interesting);
    if (immediate || sustained != null) {
      await _maybeTrigger(observation, sustainedSummary: sustained);
    }
  }

  Future<void> observeVisionContext(Map<String, Object?> contextJson) async {
    final visionContext = contextJson['vision_context'];
    if (visionContext is! Map) return;
    final activity = visionContext['activity']?.toString().trim();
    if (activity == null || activity.isEmpty) return;
    final sourceTier = int.tryParse(
      visionContext['source_tier']?.toString() ?? '',
    );
    final confidence = double.tryParse(
      visionContext['confidence']?.toString() ?? '',
    );
    final summary = 'vision_context: ${jsonEncode(visionContext)}';
    final observation = AuraObservation(
      source: AuraObservationSource.vision,
      original: summary,
      english: summary,
      summary: summary,
      translationSource: 'vision_context',
      timestamp: DateTime.now(),
      metadata: {
        'vision_context': visionContext,
        'source_tier': sourceTier,
        'confidence': confidence,
      },
    );
    _remember(observation);

    final stuck = visionContext['stuck'] == true;
    if (stuck) {
      await _maybeTrigger(
        observation,
        sustainedSummary:
            'The structured vision context says the user may be stuck. Offer one brief help check-in; otherwise reply SILENT.',
      );
    }
  }

  void rememberSystemContext(String summary, {Map<String, Object?>? metadata}) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) return;
    _remember(
      AuraObservation(
        source: AuraObservationSource.text,
        original: trimmed,
        english: trimmed,
        summary: trimmed,
        translationSource: 'system',
        timestamp: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  void _remember(AuraObservation observation) {
    _recent.add(observation);
    while (_recent.length > _maxRecent) {
      _recent.removeAt(0);
    }
    debugPrint(
      '[AURA CONTEXT] ${observation.source.name}: ${observation.summary}',
    );
  }

  Future<void> _maybeTrigger(
    AuraObservation observation, {
    String? sustainedSummary,
  }) async {
    final callback = onNaturalTrigger;
    if (callback == null) return;

    final now = DateTime.now();
    if (_lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < _globalCooldown) {
      return;
    }
    final sourceLast = _lastTriggerBySource[observation.source];
    if (sourceLast != null && now.difference(sourceLast) < _sourceCooldown) {
      return;
    }

    final signature = _signatureFor(observation);
    if (_lastSignature == signature &&
        _lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < _duplicateWindow) {
      return;
    }

    _lastTriggerAt = now;
    _lastTriggerBySource[observation.source] = now;
    _lastSignature = signature;

    final payloadMap = <String, Object?>{
      'id': -20,
      'label': 'natural_context',
      'type': observation.source.name,
      'event': observation.toJson(),
      'recent': _recent.map((entry) => entry.toJson()).toList(),
    };
    if (sustainedSummary != null) {
      payloadMap['sustained_summary'] = sustainedSummary;
    }
    final payload = jsonEncode(payloadMap);
    debugPrint(
      '[AURA CONTEXT] dispatching natural proactive event: $signature',
    );
    unawaited(callback(payload));
  }

  String _signatureFor(AuraObservation observation) {
    if (observation.source == AuraObservationSource.vision) {
      final labels = observation.metadata['interesting_labels'];
      if (labels is List && labels.isNotEmpty) {
        return '${observation.source.name}:${labels.join(",")}';
      }
    }
    final words = observation.english
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .take(5)
        .join('_');
    return '${observation.source.name}:$words';
  }
}
