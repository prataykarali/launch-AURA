part of 'vision_service.dart';

Future<void> _pollImpl(VisionService service) async {
  if (!service._running) return;
  if (service._healthPaused ||
      !ResourceGuardService.instance.shouldAcceptSensoryWork) {
    service._scheduleNext(VisionService._kIdleInterval);
    return;
  }

  try {
    final activityContext = await _captureTier1Context(service);
    if (activityContext != null) {
      service._latestContext = activityContext;
      service.onStructuredContext?.call(activityContext);
    }

    final frame = await _captureFrame(service);
    if (frame == null) {
      service._scheduleNext(VisionService._kIdleInterval);
      return;
    }

    await _updateStuckDetection(service, frame);

    // Motion detection: compare luminance histogram with previous frame.
    final hasMotion = _detectMotion(service, frame);
    service._prevFrame = frame;

    if (!hasMotion) {
      service._motionStreak = 0;
      service._scheduleNext(VisionService._kIdleInterval);
      return;
    }

    service._motionStreak++;
    debugPrint('[Vision] motion detected (streak=${service._motionStreak})');

    service._frameBucket.addLatest(frame, service._processFrame);

    // Poll faster while scene is changing.
    service._scheduleNext(
      service._motionStreak > 2
          ? VisionService._kActiveInterval
          : VisionService._kIdleInterval,
    );
  } catch (e, st) {
    debugPrint('[Vision] poll error: $e\n$st');
    service._scheduleNext(VisionService._kIdleInterval);
  }
}

Future<void> _processFrameImpl(VisionService service, Uint8List frame) async {
  if (!service._running ||
      service._healthPaused ||
      !ResourceGuardService.instance.shouldAcceptSensoryWork) {
    return;
  }

  final detections = await _analyseFrame(service, frame);
  if (detections.isEmpty) return;

  final accepted = await auraProcessVision(detections: detections);
  if (!accepted) {
    debugPrint('[Vision] Rust vision queue rejected detection batch');
    return;
  }

  debugPrint('[Vision] sent ${detections.length} detection(s) to Rust');
  final labels = detections.map((d) => d.label).toList(growable: false);
  final confidence = detections.isEmpty
      ? 0.0
      : detections.map((d) => d.confidence).reduce((a, b) => a + b) /
            detections.length;
  service.onDetectionSent?.call(labels, confidence);

  final tier2 = await _captureTier2DetailIfUseful(service, frame, labels);
  if (tier2 != null) {
    service._latestContext = tier2;
    service.onStructuredContext?.call(tier2);
  }
}

bool _shouldTriggerCapture(String text) {
  final lower = text.toLowerCase();
  return _visionTriggerVocabulary.any(lower.contains);
}
