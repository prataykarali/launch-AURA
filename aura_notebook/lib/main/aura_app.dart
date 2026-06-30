import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:aura_notebook/bar/bar_multi_window_service.dart';
import 'package:aura_notebook/main/aura_root.dart';
import 'package:aura_notebook/main/open_main_app.dart';
import 'package:aura_notebook/services/android_overlay_service.dart';
import 'package:aura_notebook/services/bar_brain.dart';
import 'package:aura_notebook/services/resource_guard_service.dart';
import 'package:aura_notebook/services/stt_service.dart';
import 'package:aura_notebook/services/tts_service.dart';

class AuraApp extends StatefulWidget {
  const AuraApp({super.key});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp>
    with WindowListener, WidgetsBindingObserver {
  final bool _isDesktop =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  bool _isMainHidden = false;

  // Root navigator key shared with AndroidOverlayService so showBar() can
  // resolve a live ScaffoldMessenger even when its caller's widget (e.g.
  // LoadingScreen) has been unmounted. This is what makes the
  // permission-denied SnackBar actually appear instead of silently no-op'ing.
  static final GlobalKey<NavigatorState> _rootNavKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AndroidOverlayService.rootNavigatorKey = _rootNavKey;
    ResourceGuardService.instance.start(
      onCritical: AuraBarBrain.instance.handleResourcePressure,
    );
    if (_isDesktop) {
      windowManager.addListener(this);
    }
    // On Android, observe app lifecycle so that when the user returns from
    // granting "Display over other apps" permission in Settings we can retry
    // showing the overlay bar — previously it would never appear even after
    // the permission was granted, because showBar() had already bailed once.
    if (!_isDesktop) {
      WidgetsBinding.instance.addObserver(this);
    }
    _installWindowMethodHandler();
  }

  @override
  void dispose() {
    // Single merged dispose: handle BOTH the mobile lifecycle observer and the
    // desktop window listener. Previously two separate dispose() overrides
    // existed (duplicate_definition), the second silently shadowing the first,
    // so the WidgetsBinding observer was never removed on Android.
    if (!_isDesktop) {
      WidgetsBinding.instance.removeObserver(this);
    }
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    ResourceGuardService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume: if permission was granted while the user was in Settings but
    // the overlay still isn't showing, retry now. This closes the gap where
    // showBar() bailed on first run (permission not yet granted) and never
    // got a second chance.
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      unawaited(
        AndroidOverlayService.retryIfNotActive(
          muted: AuraBarBrain.instance.isMuted,
        ),
      );
    }
  }

  Future<void> _installWindowMethodHandler() async {
    if (!_isDesktop) return;

    try {
      final current = await WindowController.fromCurrentEngine();
      debugPrint('MainApp: current window ID is ${current.windowId}');

      await current.setWindowMethodHandler((call) async {
        debugPrint(
          'MainApp: received IPC from window method="${call.method}" args="${call.arguments}"',
        );
        if (call.method == 'window_close') {
          onWindowClose();
          return true;
        }
        if (call.method == 'sub_window_closed') {
          unawaited(AuraBarBrain.instance.cancelCurrentOps());
          return true;
        }
        if (call.method == 'mic_tap') {
          unawaited(AuraBarBrain.instance.handleMicTap());
          return true;
        }
        if (call.method == 'speaker_tap') {
          unawaited(
            AuraBarBrain.instance.speakResponse(
              AuraBarBrain.instance.currentResponse,
            ),
          );
          return true;
        }
        if (call.method == 'ask_tap') {
          unawaited(openMainApp());
          return true;
        }
        if (call.method == 'volume_tap') {
          AuraBarBrain.instance.toggleVolume();
          // Push the authoritative mute state back to the bar window so its
          // speaker icon re-syncs from the main process (not just its own
          // optimistic tap). We echo the CURRENT bar state so toggling volume
          // mid-speech doesn't knock the bar back to idle — only the mute flag
          // changes. The desktop multi-window payload includes `muted`.
          await AuraBarMultiWindowService.instance.sendState(
            AuraBarBrain.instance.currentState,
            muted: AuraBarBrain.instance.isMuted,
          );
          return true;
        }
        if (call.method == 'volume_set') {
          final v = double.tryParse('${call.arguments}') ?? 1.0;
          AuraBarBrain.instance.setVolume(v);
          return true;
        }
        if (call.method == 'submit_text') {
          final text = call.arguments?.toString() ?? '';
          if (text.isNotEmpty) {
            unawaited(AuraBarBrain.instance.processUserPrompt(text));
          }
          return true;
        }
        if (call.method == 'stop_tts') {
          AuraTTSService.instance.setPlaybackSuppressed(true);
          unawaited(AuraBarBrain.instance.cancelCurrentOps());
          return true;
        }
        return false;
      });
    } catch (e) {
      debugPrint('Error installing main window method handler: $e');
    }
  }

  @override
  void onWindowClose() async {
    if (!_isDesktop) return;

    // MASTER ENGINE PROTECTION:
    // On Linux, destroying the implicit view (id 0) kills the entire process.
    // We hide the main window instead to keep the sub-windows alive.
    // Only exit if this is truly the last window.

    final windows = await WindowController.getAll();
    if (windows.length <= 1) {
      await _shutdownVoiceServices();
      exit(0);
    } else {
      await windowManager.setPreventClose(true);
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
      _isMainHidden = true;
    }
  }

  Future<void> _shutdownVoiceServices() async {
    try {
      await AuraTTSService.instance.stop();
    } catch (e) {
      debugPrint('AURA shutdown: TTS stop failed: $e');
    }
    try {
      await AuraSTTService.instance.dispose();
    } catch (e) {
      debugPrint('AURA shutdown: STT dispose failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      navigatorKey: _rootNavKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const AuraRoot(),
    );
  }
}
