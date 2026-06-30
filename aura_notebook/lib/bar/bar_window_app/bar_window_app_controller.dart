import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../bar_state.dart';
import '../../src/rust/frb_generated.dart';
import 'bar_window_app_host.dart';
import 'bar_window_app_ipc.dart';

class BarWindowAppController {
  final BarWindowAppHost _host;
  late final BarWindowAppIpc _ipc;

  BarWindowAppController(this._host) {
    _ipc = BarWindowAppIpc(_host);
  }

  static const double _kWindowWidth = 760;
  static const double _kCompactHeight = 96;
  static const double _kBubbleHeight = 220;

  final ValueNotifier<BarState> barState = ValueNotifier<BarState>(BarState.idle);
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);
  final ValueNotifier<bool> hasResponse = ValueNotifier<bool>(false);
  // Local mute mirror. The bar window is a separate isolate that does NOT own
  // the audio engine or AuraBarBrain.engineReady (those live in the main
  // window). All voice/volume actions are forwarded to the main window via IPC
  // (see _invokeMain below); the main window pushes the authoritative mute flag
  // back via 'set_state' payloads (see _applyState). This local mirror is only
  // for instant icon feedback — the real muting happens in the main process.
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  StreamSubscription<String>? _chatSubscription;

  Future<void> init() async {
    await _initRust();
    await _installMethodHandler();
    await _initBarWindow();
  }

  void dispose() {
    _chatSubscription?.cancel();
    barState.dispose();
    message.dispose();
    isMutedNotifier.dispose();
  }

  Future<void> _initRust() async {
    try {
      await RustLib.init();
      debugPrint('AURA_BAR: RustLib initialized in child window.');
    } catch (e) {
      if (!e.toString().contains('initialize flutter_rust_bridge twice')) {
        debugPrint('AURA_BAR: RustLib init error: $e');
      }
    }
  }

  Future<void> _initBarWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setResizable(false);
    // Start compact so the transparent child window does not block clicks on
    // apps behind it. It grows only while an actual response/proactive bubble
    // is visible.
    await windowManager.setSize(const Size(_kWindowWidth, _kCompactHeight));
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    // Try setFocusable (added in window_manager 0.4.0). Some compositors
    // drop click events on transparent frameless child windows unless the
    // window is explicitly marked focusable. Guarded because older plugin
    // versions don't expose the method.
    try {
      // ignore: avoid_dynamic_calls
      await (windowManager as dynamic).setFocusable(true);
    } catch (_) {
      // Plugin version doesn't support setFocusable — rely on default.
    }

    // Repeated attempts to force transparency if compositor is laggy
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
      await windowManager.setBackgroundColor(const Color(0x00000000));
      try {
        await windowManager.setHasShadow(false);
      } catch (_) {
        // Some Linux child windows do not register this optional method.
      }
    }
  }

  Future<void> showAndFocus() async {
    await _host.controller?.show();
    try {
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _installMethodHandler() async {
    final controller = _host.controller;
    if (controller == null) return;

    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'focus_bar':
          await showAndFocus();
          return true;
        case 'set_state':
          _applyState(call.arguments);
          return true;
        case 'show_message':
          final text = call.arguments?.toString();
          barState.value = BarState.proactive;
          message.value = text == null || text.isEmpty ? null : text;
          return true;
        case 'clear_message':
          message.value = null;
          if (barState.value == BarState.proactive) {
            barState.value = BarState.idle;
          }
          return true;
        case 'close_bar':
          await close();
          return true;
        case 'window_close':
          await close();
          return true;
        default:
          throw MissingPluginException('Unknown bar method: ${call.method}');
      }
    });
  }

  void _applyState(dynamic arguments) {
    if (arguments is! Map) return;
    final stateName = arguments['state']?.toString();
    final msg = arguments['message']?.toString();
    // The main window (audio owner) pushes the authoritative mute flag with
    // every state update (see main.dart volume_tap handler). Honor it so this
    // isolate's speaker icon stays in sync with the real audio state instead
    // of only its own optimistic local toggle.
    final muted = arguments['muted'];
    if (muted is bool) isMutedNotifier.value = muted;

    final nextState = BarState.values.firstWhere(
      (state) => state.name == stateName,
      orElse: () => BarState.idle,
    );
    barState.value = nextState;
    final nextMessage = msg == null || msg.isEmpty ? null : msg;
    message.value = nextMessage;
    unawaited(_resizeForState(nextState, nextMessage));
    if (nextMessage != null && nextMessage.trim().isNotEmpty) {
      hasResponse.value = true;
    }
  }

  Future<void> _resizeForState(BarState state, String? msg) async {
    final needsBubble = switch (state) {
      BarState.proactive ||
      BarState.speaking ||
      BarState.warning ||
      BarState.learning ||
      BarState.watching => true,
      _ => msg != null && msg.trim().isNotEmpty,
    };
    final height = needsBubble ? _kBubbleHeight : _kCompactHeight;
    try {
      await windowManager.setSize(Size(_kWindowWidth, height));
    } catch (_) {}
    await _ipc.resize(_kWindowWidth.round(), height.round());
  }

  Future<void> close() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Stop any ongoing TTS playback in the main window before closing.
      await _ipc.invokeMain('stop_tts');
      await windowManager.hide();
      await _ipc.notifyMainClosing();
    }
  }

  void onMicTap() => unawaited(_ipc.invokeMain('mic_tap'));
  void onAskTap() => unawaited(_ipc.invokeMain('ask_tap'));
  void onSpeakerTap() => unawaited(_ipc.invokeMain('speaker_tap'));

  void onVolumeToggle() {
    // Optimistic local toggle for instant icon feedback; the main
    // window will push the authoritative flag back via set_state.
    isMutedNotifier.value = !isMutedNotifier.value;
    unawaited(_ipc.invokeMain('volume_tap'));
  }

  void onPointerDown(PointerDownEvent e) => _ipc.onPointerDown(e);
  void onPointerMove(PointerMoveEvent e) => _ipc.onPointerMove(e);
  void onPointerUp(PointerUpEvent e) => _ipc.onPointerUp(e);
  void onPointerCancel(PointerCancelEvent e) => _ipc.onPointerCancel(e);

  /// Handle text submission by forwarding to the MAIN window via IPC.
  ///
  /// The bar window is a separate isolate that does NOT own the engine, so
  /// calling AuraBarBrain.processUserPrompt() here would hit the
  /// `if (!engineReady)` guard (engineReady is only set true in the main
  /// window after auraInit) and queue the prompt forever.
  ///
  /// OPTIMISTIC UI: We switch to processing state locally so the user sees
  /// instant feedback even if the main window is busy with auraInit (~8s).
  void handleSubmitText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Instant local feedback
    barState.value = BarState.processing;
    message.value = "Just a moment...";

    _chatSubscription?.cancel();
    _chatSubscription = null;

    // FIRE-AND-FORGET: Don't await the main window's response here. The main
    // window might be busy with auraInit, and awaiting here would block the
    // bar window's own interaction.
    unawaited(_ipc.invokeMain('submit_text', trimmed));
  }
}
