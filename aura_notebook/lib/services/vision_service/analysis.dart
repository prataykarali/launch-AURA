part of 'vision_service.dart';

// ── Frame analysis ────────────────────────────────────────────────────────
//
// Produces VisionDetection objects from the frame.
//
// Tier 1 (implemented): simple heuristic pixel stats → "bright scene",
//   "dim scene", "screen content" — enough for the pipeline to function.
// Tier 2 (TODO): plug in ML Kit OCR + YOLO via MethodChannel when ready.

Future<List<VisionDetection>> _analyseFrame(VisionService service, Uint8List frame) async {
  // Compute average luminance and simple scene labels.
  final luma = _averageLuma(frame);
  final detections = <VisionDetection>[];

  if (luma > 180) {
    detections.add(
      const VisionDetection(label: 'bright_scene', confidence: 0.45),
    );
  } else if (luma < 40) {
    detections.add(
      const VisionDetection(label: 'dim_scene', confidence: 0.45),
    );
  } else {
    detections.add(
      const VisionDetection(label: 'normal_scene', confidence: 0.4),
    );
  }

  // On Linux we can also add "screen" label since we captured a screenshot.
  if (Platform.isLinux) {
    detections.add(
      const VisionDetection(label: 'screen_visible', confidence: 0.55),
    );
    for (final label in _labelsFromWindowTitle(service._lastActiveWindow)) {
      detections.add(VisionDetection(label: label, confidence: 0.5));
    }
  } else if (Platform.isAndroid) {
    detections.addAll(service._lastAndroidDetections);
  }

  return _dedupeDetections(detections);
}

List<VisionDetection> _dedupeDetections(List<VisionDetection> detections) {
  final byLabel = <String, VisionDetection>{};
  for (final detection in detections) {
    final key = detection.label.trim();
    if (key.isEmpty) continue;
    final existing = byLabel[key];
    if (existing == null || detection.confidence > existing.confidence) {
      byLabel[key] = detection;
    }
  }
  final values = byLabel.values.toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return values.take(6).toList(growable: false);
}

List<String> _labelsFromWindowTitle(String? title) {
  if (title == null || title.trim().isEmpty) return const [];
  final lower = title.toLowerCase();
  final labels = <String>{};

  if (lower.contains('.rs') ||
      lower.contains('rust') ||
      lower.contains('cargo') ||
      lower.contains('codium') ||
      lower.contains('visual studio code') ||
      lower.contains('vscode') ||
      lower.contains('intellij') ||
      lower.contains('zed') ||
      lower.contains('neovim') ||
      lower.contains('vim')) {
    labels.add('coding');
    labels.add('focused_work');
    labels.add('ide_active');
    if (lower.contains('rust') ||
        lower.contains('.rs') ||
        lower.contains('cargo')) {
      labels.add('rust_practice');
    }
  }
  if (lower.contains('terminal') ||
      lower.contains('bash') ||
      lower.contains('zsh') ||
      lower.contains('fish') ||
      lower.contains('konsole') ||
      lower.contains('gnome-terminal')) {
    labels.add('terminal_active');
    labels.add('focused_work');
  }
  if (lower.contains('reels') ||
      lower.contains('shorts') ||
      lower.contains('tiktok') ||
      lower.contains('instagram') ||
      lower.contains('youtube') ||
      lower.contains('facebook watch')) {
    labels.add('short_video');
    labels.add('social_scroll');
    labels.add('video_break');
  }
  if (lower.contains('pdf') ||
      lower.contains('libreoffice') ||
      lower.contains('document') ||
      lower.contains('notes') ||
      lower.contains('notion')) {
    labels.add('study_session');
  }
  return labels.toList(growable: false);
}
