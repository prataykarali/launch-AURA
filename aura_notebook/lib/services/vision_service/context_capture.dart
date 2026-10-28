part of 'vision_service.dart';

Future<AuraVisionContext?> _captureTier1Context(VisionService service) async {
  final profile = service.deviceProfile;
  if (!_canRunTier1For(profile)) {
    // mobileMinimal: return a basic context so the brain knows the device
    // is alive, even if we can't detect the foreground app.
    if (profile == AuraVisionDeviceProfile.mobileMinimal) {
      return AuraVisionContext(
        activity: 'device_active',
        detail: null,
        stuck: false,
        stuckDurationMins: 0,
        sourceTier: 0,
        deviceProfile: profile,
        confidence: 0.3,
      );
    }
    return null;
  }

  if (Platform.isAndroid) {
    final packageName = await _androidForegroundPackage(service);
    return AuraVisionContext(
      activity: _activityFromAndroidPackage(packageName),
      detail: packageName,
      stuck: false,
      stuckDurationMins: 0,
      sourceTier: packageName == null ? 0 : 1,
      deviceProfile: profile,
      confidence: packageName == null ? 0.0 : 0.75,
    );
  }

  final title =
      service._lastActiveWindow ?? await _readLinuxActiveWindowTitle();
  final activity = _activityFromWindowTitle(title);
  final screenText = service._lastScreenText;
  final detail = screenText != null && screenText.trim().isNotEmpty
      ? screenText.trim()
      : (title == null || title.trim().isEmpty ? null : title.trim());
  return AuraVisionContext(
    activity: activity,
    detail: detail,
    stuck: service._sameOcrHashCount >= 10,
    stuckDurationMins: _stuckDurationMins(service),
    sourceTier: screenText != null ? 2 : 1,
    deviceProfile: profile,
    confidence: screenText != null ? 0.9 : 0.75,
  );
}

Future<AuraVisionContext?> _captureTier2DetailIfUseful(
  VisionService service,
  Uint8List frame,
  List<String> labels,
) async {
  final profile = service.deviceProfile;
  if (!_canRunTier2For(profile)) return null;

  final base = service._latestContext;
  final activity =
      base?.activity ?? _activityFromWindowTitle(service._lastActiveWindow);
  if (activity != 'browsing' && activity != 'video' && activity != 'unknown') {
    return null;
  }

  final detail = await _runMoondreamDetail(frame);
  if (detail == null || detail.trim().isEmpty) return null;
  return AuraVisionContext(
    activity: activity,
    detail: detail.trim(),
    stuck: service._sameOcrHashCount >= 10,
    stuckDurationMins: _stuckDurationMins(service),
    sourceTier: 2,
    deviceProfile: profile,
    confidence: 0.85,
  );
}

Future<String?> _runMoondreamDetail(Uint8List frame) async {
  final runner = Platform.environment['AURA_MOONDREAM_CMD']?.trim();
  if (runner == null || runner.isEmpty) return null;
  final id = _captureCounter++;
  final tmp = '/tmp/_aura_moondream_frame_$id.jpg';
  try {
    await File(tmp).writeAsBytes(frame, flush: true);
    final result = await Process.run(runner, [
      tmp,
      'In one sentence, what is the user doing on this screen? Be specific about the application and task.',
    ]).timeout(const Duration(seconds: 8));
    if (result.exitCode != 0) return null;
    final out = result.stdout.toString().trim();
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  } finally {
    try {
      await File(tmp).delete();
    } catch (_) {}
  }
}
