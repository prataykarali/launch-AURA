part of 'vision_service.dart';

// Unique temp file per capture to avoid concurrent write races.
int _captureCounter = 0;

// Linux — take a screenshot via grim (Wayland), scrot, or import (X11).
Future<Uint8List?> _captureLinuxScreenshot(VisionService service) async {
  try {
    service._lastActiveWindow = await _readLinuxActiveWindowTitle();
    final id = _captureCounter++;
    final tmp = '/tmp/_aura_vision_frame_$id.jpg';

    // Try grim first (Wayland-native), then scrot, then import (X11).
    // Capture at full resolution with quality 85 for reliable OCR.
    // Previous --thumb 320 produced a 320px thumbnail too small for tesseract.
    var result = await Process.run('grim', [
      '-t',
      'jpeg',
      '-q',
      '85',
      tmp,
    ], runInShell: true).timeout(const Duration(seconds: 5));

    if (result.exitCode != 0) {
      result = await Process.run('scrot', [
        '-q',
        '85',
        tmp,
      ], runInShell: true).timeout(const Duration(seconds: 5));
    }

    if (result.exitCode != 0) {
      result = await Process.run('import', [
        '-window',
        'root',
        '-quality',
        '85',
        '-resize',
        '1280',
        tmp,
      ], runInShell: true).timeout(const Duration(seconds: 5));
    }

    if (result.exitCode != 0) return null;
    final file = File(tmp);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<String?> _readLinuxActiveWindowTitle() async {
  // Check if the active window is the AURA Bar — if so, fall through to
  // the Z-order fallback to find the REAL focused app behind the bar.
  // The bar is always-on-top, so xdotool getactivewindow often returns it.
  try {
    var result = await Process.run('xdotool', [
      'getactivewindow',
      'getwindowname',
    ], runInShell: true).timeout(const Duration(milliseconds: 500));
    if (result.exitCode == 0) {
      final title = result.stdout.toString().trim();
      if (title.isNotEmpty && !_isAuraBarWindow(title)) return title;
    }
  } catch (_) {}

  // Fallback 1: list visible windows in Z-order, skip AURA Bar, return topmost.
  try {
    final result = await Process.run('sh', [
      '-lc',
      'xdotool search --onlyvisible --class "" 2>/dev/null | '
          'while read wid; do '
          'name=\$(xdotool getwindowname "\$wid" 2>/dev/null); '
          'if [ -n "\$name" ] && ! echo "\$name" | grep -qi "aura.bar\\|aura bar\\|aura_bar"; then '
          'echo "\$name"; break; '
          'fi; done',
    ], runInShell: true).timeout(const Duration(milliseconds: 700));
    if (result.exitCode == 0) {
      final title = result.stdout.toString().trim();
      if (title.isNotEmpty) return title;
    }
  } catch (_) {}

  // Fallback 2: xprop _NET_ACTIVE_WINDOW with AURA Bar filtering.
  try {
    final result = await Process.run('sh', [
      '-lc',
      'xprop -root _NET_ACTIVE_WINDOW | awk \'{print \$5}\' | xargs -I{} xprop -id {} WM_NAME',
    ], runInShell: true).timeout(const Duration(milliseconds: 700));
    if (result.exitCode == 0) {
      final raw = result.stdout.toString();
      final match = RegExp(r'"([^"]+)"').firstMatch(raw);
      final title = match?.group(1)?.trim();
      if (title != null && title.isNotEmpty && !_isAuraBarWindow(title))
        return title;
    }
  } catch (_) {}
  return null;
}

bool _isAuraBarWindow(String title) {
  final lower = title.toLowerCase();
  return lower.contains('aura bar') ||
      lower.contains('aura_bar') ||
      lower.contains('aura.bar');
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
