import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'package:aura_notebook/services/bar_brain.dart';

Future<void> openMainApp() async {
  // Block if bar is mid-processing — prevents home redirection from
  // tearing down an active LLM/TTS pipeline.
  if (AuraBarBrain.instance.isProcessing) {
    debugPrint('[AURA] openMainApp blocked — bar is processing');
    return;
  }

  // Show brief processing state in the bar for smooth transition to option screen.
  await AuraBarBrain.instance.showProcessingTransition('Opening AURA...');
  await Future.delayed(const Duration(milliseconds: 300));

  if (Platform.isAndroid) {
    try {
      await const MethodChannel("aura/main_app").invokeMethod("open_app");
    } catch (e) {
      debugPrint("Error opening main app on Android: $e");
    }
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }
}
