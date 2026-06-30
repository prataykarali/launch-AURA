part of 'vision_service.dart';

Future<void> _updateStuckDetection(VisionService service, Uint8List frame) async {
  final profile = service.deviceProfile;
  if (!_canRunTier3For(profile)) return;
  final now = DateTime.now();
  if (service._lastStuckOcrAt != null &&
      now.difference(service._lastStuckOcrAt!) < const Duration(seconds: 30)) {
    return;
  }
  service._lastStuckOcrAt = now;

  final text = await _ocrFrame(service, frame);
  if (text == null || text.trim().isEmpty) {
    _resetStuckState(service);
    return;
  }
  final hash = _stableTextHash(text);
  if (service._lastOcrHash == hash) {
    service._sameOcrHashCount++;
    service._stuckStartedAt ??= now;
  } else {
    service._lastOcrHash = hash;
    service._sameOcrHashCount = 1;
    service._stuckEpisodeFired = false;
    service._stuckStartedAt = now;
  }
}

Future<String?> _ocrFrame(VisionService service, Uint8List frame) async {
  final tmp = '/tmp/_aura_ocr_frame.jpg';
  try {
    await File(tmp).writeAsBytes(frame, flush: true);
    final result = await Process.run('tesseract', [
      tmp,
      'stdout',
      '--psm',
      '6',
    ]).timeout(const Duration(seconds: 4));
    if (result.exitCode != 0) return null;
    return result.stdout.toString();
  } catch (_) {
    return null;
  } finally {
    try {
      await File(tmp).delete();
    } catch (_) {}
  }
}

String _stableTextHash(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
  var hash = 5381;
  for (final unit in normalized.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return hash.toUnsigned(32).toRadixString(16);
}

void _resetStuckState(VisionService service) {
  service._lastOcrHash = null;
  service._sameOcrHashCount = 0;
  service._stuckEpisodeFired = false;
  service._stuckStartedAt = null;
}

int _stuckDurationMins(VisionService service) {
  final started = service._stuckStartedAt;
  if (started == null) return 0;
  return DateTime.now().difference(started).inMinutes;
}

bool _consumeStuckEpisodeTrigger(VisionService service) {
  if (service._sameOcrHashCount < 10 || service._stuckEpisodeFired) return false;
  service._stuckEpisodeFired = true;
  return true;
}
