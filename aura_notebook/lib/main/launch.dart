import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:aura_notebook/bar/bar_multi_window_service.dart';
import 'package:aura_notebook/bar/bar_window_app.dart';
import 'package:aura_notebook/main/aura_app.dart';
import 'package:aura_notebook/services/stt_service.dart';
import 'package:aura_notebook/src/rust/frb_generated.dart';

Future<void> runAura(List<String> rawArgs) async {
  WidgetsFlutterBinding.ensureInitialized();
  AuraSTTService.isMainApp = true;

  final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  // Asynchronous pre-warming of Rust bindings and Rayon thread configuration on mobile
  if (!isDesktop) {
    unawaited(
      Future(() async {
        try {
          await RustLib.init();
          await RustLib.instance.api.crateApiConfigConfigureRayonThreads();
          debugPrint('RustLib and Rayon threads successfully pre-warmed.');
        } catch (e) {
          debugPrint('RustLib pre-warm error: $e');
        }
      }),
    );
  }

  final rawWindowArgs = _resolveLaunchArguments(rawArgs, null);
  final isRawBarWindow = rawWindowArgs['type'] == kAuraBarWindowType;

  if (isDesktop) {
    await windowManager.ensureInitialized();
  }

  final currentWindow = await _currentWindowController();
  final args = rawWindowArgs.isNotEmpty
      ? rawWindowArgs
      : _resolveLaunchArguments(rawArgs, currentWindow?.arguments);
  if (isDesktop && args['type'] == kAuraBarWindowType) {
    runApp(BarWindowApp(controller: currentWindow));
    return;
  }

  if (isDesktop) {
    await windowManager.setTitle('AURA');
    await windowManager.setPreventClose(true);
    await windowManager
        .hide(); // Hide main app window so it doesn't pop up on start
  }
  runApp(const AuraApp());
}

Map<String, dynamic> _resolveLaunchArguments(
  List<String> rawArgs,
  String? controllerArgs,
) {
  final fromController = parseWindowArguments(controllerArgs ?? '');
  if (fromController.isNotEmpty) return fromController;

  if (rawArgs.length >= 3 && rawArgs.first == 'multi_window') {
    return parseWindowArguments(rawArgs[2]);
  }

  for (final arg in rawArgs) {
    final parsed = parseWindowArguments(arg);
    if (parsed.isNotEmpty) return parsed;
  }

  return const {};
}

Future<WindowController?> _currentWindowController() async {
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return null;
  }

  try {
    return await WindowController.fromCurrentEngine();
  } catch (_) {
    return null;
  }
}
