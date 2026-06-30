part of 'vision_service.dart';

Future<String?> _androidForegroundPackage(VisionService service) async {
  if (!Platform.isAndroid) return null;
  try {
    final hasAccess =
        await VisionService._androidVisionChannel.invokeMethod<bool>('has_usage_access') ??
        false;
    if (!hasAccess) {
      if (!service._usageAccessRequested) {
        service._usageAccessRequested = true;
        await VisionService._androidVisionChannel.invokeMethod<bool>(
          'request_usage_access',
        );
      }
      return null;
    }
    final packageName = await VisionService._androidVisionChannel.invokeMethod<String>(
      'foreground_app',
    );
    final trimmed = packageName?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  } catch (e) {
    debugPrint('[Vision] Android foreground app query failed: $e');
    return null;
  }
}

String _activityFromAndroidPackage(String? packageName) {
  final lower = (packageName ?? '').toLowerCase();
  if (lower.isEmpty) return 'listen_only';
  if (lower.contains('termux') ||
      lower.contains('terminal') ||
      lower.contains('juicessh')) {
    return 'terminal';
  }
  if (lower.contains('github') ||
      lower.contains('code') ||
      lower.contains('aide') ||
      lower.contains('replit')) {
    return 'coding';
  }
  if (lower.contains('youtube') ||
      lower.contains('netflix') ||
      lower.contains('tiktok') ||
      lower.contains('instagram')) {
    return 'video';
  }
  if (lower.contains('chrome') ||
      lower.contains('firefox') ||
      lower.contains('browser') ||
      lower.contains('brave')) {
    return 'browsing';
  }
  if (lower.contains('steam') ||
      lower.contains('game') ||
      lower.contains('roblox') ||
      lower.contains('minecraft')) {
    return 'gaming';
  }
  return 'unknown';
}
