import 'dart:convert';
import 'dart:io';
import '../services/android_overlay_service.dart';
import '../services/tts_service.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import 'bar_state.dart';

const String kAuraBarWindowType = 'aura_bar';

class WindowInfo {
  final String id;
  final WindowController controller;
  final String name;

  const WindowInfo({
    required this.id,
    required this.controller,
    required this.name,
  });
}

class AuraBarMultiWindowService {
  AuraBarMultiWindowService._();
  static final AuraBarMultiWindowService instance =
      AuraBarMultiWindowService._();

  WindowInfo? _barWindow;
  bool _opening = false;

  bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Future<WindowInfo?> showOrCreateBar({
    BarState state = BarState.idle,
    String? proactiveMessage,
    bool? muted,
  }) async {
    AuraTTSService.instance.setPlaybackSuppressed(false);
    if (Platform.isAndroid) {
      await AndroidOverlayService.showBar();
      await AndroidOverlayService.updateState(
        state,
        message: proactiveMessage,
        muted: muted,
      );
      return null;
    }
    if (!_isDesktop || _opening) return _barWindow;
    _opening = true;

    try {
      final existing = await _findExistingBarWindow();
      if (existing != null) {
        _barWindow = existing;
        await _focus(existing.controller);
        await _sendState(existing.controller, state, proactiveMessage, muted);
        return existing;
      }

      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({
            'type': kAuraBarWindowType,
            'name': 'AURA Bar',
          }),
        ),
      );

      final info = WindowInfo(
        id: controller.windowId,
        controller: controller,
        name: 'AURA Bar',
      );
      _barWindow = info;

      await controller.show();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _sendState(controller, state, proactiveMessage, muted);
      return info;
    } catch (e, st) {
      debugPrint('AURA_BAR_WINDOW_ERROR: $e\n$st');
      _barWindow = null;
      return null;
    } finally {
      _opening = false;
    }
  }

  Future<void> closeBar() async {
    AuraTTSService.instance.setPlaybackSuppressed(true);
    if (Platform.isAndroid) {
      await AndroidOverlayService.closeBar();
      return;
    }
    final info = _barWindow ?? await _findExistingBarWindow();
    if (info == null) return;
    try {
      await info.controller.invokeMethod('close_bar');
    } catch (e) {
      debugPrint('AURA_BAR_CLOSE_ERROR: $e');
    } finally {
      _barWindow = null;
    }
  }

  BarState? _lastSentState;
  String? _lastSentMessage;
  bool? _lastSentMuted;

  Future<void> sendState(
    BarState state, {
    String? proactiveMessage,
    bool? muted,
  }) async {
    if (Platform.isAndroid) {
      await AndroidOverlayService.updateState(
        state,
        message: proactiveMessage,
        muted: muted,
      );
      return;
    }

    // REDUNDANCY GUARD: avoid expensive IPC if the state and message are identical.
    if (state == _lastSentState &&
        proactiveMessage == _lastSentMessage &&
        muted == _lastSentMuted) {
      return;
    }

    // CACHING FIX: previously _findExistingBarWindow() results were never
    // saved back to _barWindow in this path, so EVERY throttled token update
    // triggered a full WindowController.getAll() round-trip. Caching the
    // handle here makes subsequent IPC updates significantly faster.
    var info = _barWindow;
    if (info == null) {
      info = await _findExistingBarWindow();
      _barWindow = info;
    }

    if (info == null) return;

    _lastSentState = state;
    _lastSentMessage = proactiveMessage;
    _lastSentMuted = muted;

    await _sendState(info.controller, state, proactiveMessage, muted);
  }

  Future<WindowInfo?> _findExistingBarWindow() async {
    // If we already have a handle, don't bother with the expensive getAll()
    if (_barWindow != null) return _barWindow;

    try {
      final windows = await WindowController.getAll();
      for (final controller in windows) {
        final args = _decodeArgs(controller.arguments);
        if (args['type'] == kAuraBarWindowType) {
          final info = WindowInfo(
            id: controller.windowId,
            controller: controller,
            name: args['name']?.toString() ?? 'AURA Bar',
          );
          _barWindow = info;
          return info;
        }
      }
    } catch (e) {
      debugPrint('AURA_BAR_FIND_ERROR: $e');
    }
    return null;
  }

  Future<void> _focus(WindowController controller) async {
    try {
      await controller.invokeMethod('focus_bar');
    } catch (e) {
      debugPrint('AURA_BAR_FOCUS_WARN: $e');
      await controller.show();
    }
  }

  Future<void> _sendState(
    WindowController controller,
    BarState state,
    String? proactiveMessage,
    bool? muted,
  ) async {
    // REDUCED RETRY: 250ms was too long for a single frame update. We now retry
    // up to 6 times with a 40ms delay (~240ms total), which is enough to catch
    // a sub-window mid-startup but fast enough to not freeze the main loop if
    // a channel is genuinely broken.
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final payload = <String, dynamic>{
          'state': state.name,
          'message': proactiveMessage,
        };
        // Desktop bar window also understands the authoritative mute flag, so
        // it can re-sync its speaker icon from the main window instead of only
        // from its own optimistic tap.
        if (muted != null) payload['muted'] = muted;
        await controller.invokeMethod('set_state', payload);
        return;
      } catch (e) {
        if (attempt == 5) {
          debugPrint('AURA_BAR_STATE_WARN: $e');
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
  }
}

Map<String, dynamic> parseWindowArguments(String arguments) {
  return _decodeArgs(arguments);
}

Map<String, dynamic> _decodeArgs(String arguments) {
  if (arguments.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(arguments);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return const {};
  }
  return const {};
}
