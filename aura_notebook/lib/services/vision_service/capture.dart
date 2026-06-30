part of 'vision_service.dart';

Future<void> _captureNow(VisionService service, {String reason = 'explicit'}) async {
  if (Platform.isAndroid) {
    service._latestContext =
        await _captureTier1Context(service) ??
        AuraVisionContext(
          activity: 'listen_only',
          detail: service.deviceProfile == AuraVisionDeviceProfile.mobileFull
              ? 'Android screen capture is unavailable; ask the user to describe it.'
              : 'Low-end Android profile: no visual perception enabled.',
          stuck: false,
          stuckDurationMins: 0,
          sourceTier: 0,
          deviceProfile: service.deviceProfile,
        );
    service.onStructuredContext?.call(service._latestContext!);
    return;
  }
  if (!service._running) service.start();
  if (service._healthPaused ||
      !ResourceGuardService.instance.shouldAcceptSensoryWork) {
    return;
  }
  final frame = await _captureFrame(service);
  if (frame == null) return;
  service._prevFrame = frame;
  await _updateStuckDetection(service, frame);
  final activityContext = await _captureTier1Context(service);
  if (activityContext != null) {
    service._latestContext = activityContext;
    service.onStructuredContext?.call(activityContext);
  }
  service._frameBucket.addLatest(frame, service._processFrame);
  debugPrint('[Vision] immediate capture queued ($reason)');
}

Future<Uint8List?> _captureFrame(VisionService service) async {
  if (Platform.isAndroid) {
    return null;
  } else if (Platform.isLinux) {
    return _captureLinuxScreenshot(service);
  }
  return null; // macOS / Windows — not implemented yet
}
