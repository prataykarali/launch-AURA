part of 'vision_service.dart';

// Linux — take a screenshot via scrot or import (imagemagick) if available.
Future<Uint8List?> _captureLinuxScreenshot(VisionService service) async {
  try {
    service._lastActiveWindow = await _readLinuxActiveWindowTitle();
    final tmp = '/tmp/_aura_vision_frame.jpg';
    var result = await Process.run('scrot', [
      '-q',
      '60',
      '--thumb',
      '320',
      tmp,
    ], runInShell: true);
    if (result.exitCode != 0) {
      // Fallback to import (ImageMagick) if scrot fails or is missing
      result = await Process.run('import', [
        '-window',
        'root',
        '-quality',
        '60',
        '-resize',
        '320',
        tmp,
      ], runInShell: true);
    }
    if (result.exitCode != 0) return null;
    final file = File(tmp);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    await file.delete(); // clean up immediately
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<String?> _readLinuxActiveWindowTitle() async {
  try {
    var result = await Process.run('xdotool', [
      'getactivewindow',
      'getwindowname',
    ], runInShell: true).timeout(const Duration(milliseconds: 500));
    if (result.exitCode == 0) {
      final title = result.stdout.toString().trim();
      if (title.isNotEmpty) return title;
    }
  } catch (_) {}

  try {
    final result = await Process.run('sh', [
      '-lc',
      'xprop -root _NET_ACTIVE_WINDOW | awk \'{print \$5}\' | xargs -I{} xprop -id {} WM_NAME',
    ], runInShell: true).timeout(const Duration(milliseconds: 700));
    if (result.exitCode == 0) {
      final raw = result.stdout.toString();
      final match = RegExp(r'"([^"]+)"').firstMatch(raw);
      final title = match?.group(1)?.trim();
      if (title != null && title.isNotEmpty) return title;
    }
  } catch (_) {}
  return null;
}

String _activityFromWindowTitle(String? title) {
  final lower = (title ?? '').toLowerCase();
  if (lower.trim().isEmpty ||
      lower.contains('screensaver') ||
      lower.contains('lock screen')) {
    return 'idle';
  }
  if (lower.contains('code') ||
      lower.contains('vs code') ||
      lower.contains('visual studio code') ||
      lower.contains('vim') ||
      lower.contains('nvim') ||
      lower.contains('neovim') ||
      lower.contains('intellij') ||
      lower.contains('zed')) {
    return 'coding';
  }
  if (lower.contains('terminal') ||
      lower.contains('bash') ||
      lower.contains('zsh') ||
      lower.contains('fish') ||
      lower.contains('konsole') ||
      lower.contains('gnome-terminal')) {
    return 'terminal';
  }
  if (lower.contains('steam') ||
      lower.contains('minecraft') ||
      lower.contains('unity') ||
      lower.contains('unreal')) {
    return 'gaming';
  }
  if (lower.contains('firefox') ||
      lower.contains('chrome') ||
      lower.contains('chromium') ||
      lower.contains('brave')) {
    if (lower.contains('youtube') ||
        lower.contains('netflix') ||
        lower.contains('video') ||
        lower.contains('fullscreen')) {
      return 'video';
    }
    return 'browsing';
  }
  return 'unknown';
}
