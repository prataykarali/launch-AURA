part of 'vision_service.dart';

Future<void> _captureNow(
  VisionService service, {
  String reason = 'explicit',
}) async {
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

  // For user-initiated captures (user asked "what's on my screen"), bypass
  // the resource guard. The user explicitly asked to see their screen —
  // don't block it just because memory pressure is high.
  final isUserAsk = reason == 'user_ask';
  if (!isUserAsk) {
    if (service._healthPaused ||
        !ResourceGuardService.instance.shouldAcceptSensoryWork) {
      return;
    }
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

  // Run screen OCR (tesseract) on the captured screenshot.
  // For user-initiated captures: always run OCR.
  // For passive captures: run OCR every ~5th frame (~20-30s at 4s polling)
  // so AURA can read the screen background without burning CPU every cycle.
  if (Platform.isLinux) {
    if (isUserAsk) {
      debugPrint(
        '[Vision] OCR starting (user_ask, frame=${frame.length} bytes)',
      );
      unawaited(
        _runScreenOcr(service, frame).catchError((e, st) {
          debugPrint('[Vision] OCR catchError: $e\n$st');
        }),
      );
    } else {
      service._passiveOcrCounter++;
      if (service._passiveOcrCounter >= 5) {
        service._passiveOcrCounter = 0;
        debugPrint(
          '[Vision] OCR starting (passive, frame=${frame.length} bytes)',
        );
        unawaited(
          _runScreenOcr(service, frame).catchError((e, st) {
            debugPrint('[Vision] OCR catchError: $e\n$st');
          }),
        );
      }
    }
  }

  service._frameBucket.addLatest(frame, service._processFrame);
  debugPrint('[Vision] immediate capture queued ($reason)');
}

/// Run tesseract OCR on a screenshot to extract text content.
/// This is what makes AURA actually READ the user's screen instead of
/// hallucinating. The extracted text is stored in the vision service's
/// _lastScreenText field and included in the next vision context.
Future<void> _runScreenOcr(VisionService service, Uint8List frame) async {
  final tmpFile = File(
    '/tmp/_aura_ocr_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  debugPrint('[Vision] OCR writing ${frame.length} bytes to ${tmpFile.path}');
  try {
    await tmpFile.writeAsBytes(frame);
    debugPrint('[Vision] OCR file written, running tesseract...');

    final result = await Process.run('tesseract', [
      tmpFile.path,
      'stdout',
      '--psm',
      '6',
    ], runInShell: true).timeout(const Duration(seconds: 10));

    debugPrint(
      '[Vision] OCR tesseract exit=${result.exitCode} stdout=${result.stdout.toString().length}B stderr=${result.stderr.toString().length}B',
    );

    final text = result.stdout.toString().trim();
    if (text.isNotEmpty) {
      service._lastScreenText = text;
      debugPrint(
        '[Vision] OCR extracted ${text.length} chars: "${text.substring(0, text.length.clamp(0, 100))}"',
      );

      if (service._latestContext != null) {
        service._latestContext = AuraVisionContext(
          activity: service._latestContext!.activity,
          detail: text.substring(0, text.length.clamp(0, 200)),
          stuck: service._latestContext!.stuck,
          stuckDurationMins: service._latestContext!.stuckDurationMins,
          sourceTier: service._latestContext!.sourceTier,
          deviceProfile: service._latestContext!.deviceProfile,
        );
        service.onStructuredContext?.call(service._latestContext!);
      }
    } else {
      service._lastScreenText = null;
      debugPrint(
        '[Vision] OCR returned empty text. stderr: ${result.stderr.toString().substring(0, result.stderr.toString().length.clamp(0, 200))}',
      );
    }
  } catch (e, st) {
    debugPrint('[Vision] OCR failed: $e\n$st');
  } finally {
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
    } catch (_) {}
  }
}

Future<Uint8List?> _captureFrame(VisionService service) async {
  if (Platform.isAndroid) {
    // Android: no screenshot capture (privacy + performance).
    // Return null — context comes from _captureTier1Context (foreground app).
    return null;
  } else if (Platform.isLinux) {
    return _captureLinuxScreenshot(service);
  } else if (Platform.isMacOS || Platform.isWindows) {
    // Not yet implemented — return null so context_capture still works.
    return null;
  }
  return null;
}
