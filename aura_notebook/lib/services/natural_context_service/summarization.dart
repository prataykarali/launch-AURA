part of 'service.dart';

extension _NaturalContextServiceSummarization on NaturalContextService {
  List<String> _interestingLabels(List<String> labels) {
    const interesting = {
      'coding',
      'rust_practice',
      'ide_active',
      'terminal_active',
      'debugging',
      'study_session',
      'reading',
      'short_video',
      'reels',
      'social_scroll',
      'video_break',
      'late_night',
      'focused_work',
      'user_waving',
      'hand_gesture',
      'hand_pose',
      'open_palm',
      'thumbs_up',
      'face_visible',
      'facial_expression',
      'smiling',
      'confused_expression',
      'focused_expression',
      'tired_expression',
      'gesture',
      'person',
    };
    final hits = <String>[];
    for (final label in labels) {
      final normalized = label
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (interesting.contains(normalized) ||
          normalized.contains('wave') ||
          normalized.contains('gesture') ||
          normalized.contains('hand_pose') ||
          normalized.contains('open_palm') ||
          normalized.contains('thumbs_up') ||
          normalized.contains('expression') ||
          normalized.contains('smiling')) {
        hits.add(normalized);
      }
    }
    return hits.toSet().toList(growable: false);
  }

  String? _sustainedSummary(List<String> labels) {
    final now = DateTime.now();
    for (final key in _firstSeenBySignal.keys.toList()) {
      final firstSeen = _firstSeenBySignal[key];
      if (firstSeen == null || now.difference(firstSeen) > NaturalContextService._sustainedWindow) {
        _firstSeenBySignal.remove(key);
        _seenCountBySignal.remove(key);
      }
    }

    String? strongest;
    for (final label in labels) {
      final firstSeen = _firstSeenBySignal.putIfAbsent(label, () => now);
      _seenCountBySignal[label] = (_seenCountBySignal[label] ?? 0) + 1;
      final age = now.difference(firstSeen);
      final count = _seenCountBySignal[label] ?? 0;
      if (age >= const Duration(minutes: 5) &&
          count >= NaturalContextService._sustainedMinObservations &&
          _isPersonalizedVisionSignal(label)) {
        strongest = label;
        break;
      }
    }

    if (strongest == null) return null;
    return 'The user has shown repeated "$strongest" context for about 5 minutes. Make a gentle personalized nudge only if it helps the user right now; otherwise reply SILENT. Never narrate raw objects.';
  }

  bool _isPersonalizedVisionSignal(String label) {
    const personalized = {
      'coding',
      'rust_practice',
      'ide_active',
      'terminal_active',
      'debugging',
      'study_session',
      'reading',
      'short_video',
      'reels',
      'social_scroll',
      'video_break',
      'late_night',
      'focused_work',
      'user_waving',
      'hand_gesture',
      'hand_pose',
      'open_palm',
      'thumbs_up',
      'confused_expression',
      'focused_expression',
      'tired_expression',
      'smiling',
    };
    return personalized.contains(label);
  }

  String? _speechProactiveSummary(String text) {
    final lower = text.toLowerCase();
    const markers = [
      'i am tired',
      "i'm tired",
      'i feel tired',
      'i am stuck',
      "i'm stuck",
      'i need help',
      'i am stressed',
      "i'm stressed",
      'i am confused',
      "i'm confused",
    ];
    if (!markers.any(lower.contains)) return null;
    return 'The user said something that may deserve a brief supportive check-in. Reply in English if useful; otherwise reply SILENT.';
  }

  String _summarizeVision({
    required List<String> labels,
    required List<String> interestingLabels,
    required String? activeWindow,
  }) {
    final parts = <String>[];
    if (interestingLabels.isNotEmpty) {
      parts.add('activity=${interestingLabels.join(", ")}');
    }
    final generic = labels
        .where(
          (label) => !label.endsWith('_scene') && label != 'screen_visible',
        )
        .where((label) => !interestingLabels.contains(label))
        .take(6)
        .toList();
    if (generic.isNotEmpty) {
      parts.add('labels=${generic.join(", ")}');
    }
    if (activeWindow != null && activeWindow.trim().isNotEmpty) {
      parts.add('active_window="${activeWindow.trim()}"');
    }
    if (parts.isEmpty) {
      parts.add('labels=${labels.take(6).join(", ")}');
    }
    return 'visual context: ${parts.join("; ")}';
  }

  String _summarizeUserText(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 120) return cleaned;
    return '${cleaned.substring(0, 117)}...';
  }
}
