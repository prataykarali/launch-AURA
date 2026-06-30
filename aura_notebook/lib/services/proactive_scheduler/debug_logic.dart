part of 'service.dart';

extension _ProactiveSchedulerDebug on ProactiveScheduler {
  Future<void> _forceOverlayPopUp() async {
    if (Platform.isAndroid) {
      try {
        await AndroidOverlayService.showBar(
          muted: AuraBarBrain.instance.isMuted,
        );
        await AndroidOverlayService.updateState(
          BarState.proactive,
          muted: AuraBarBrain.instance.isMuted,
        );
        AndroidOverlayService.verifyTranslucency(BarState.proactive);
        // Intentionally NO invokeMethod("open_app") here — forcing the main
        // window to foreground causes a flash and can steal focus from the
        // overlay during proactive triggers. The overlay is already visible.
      } catch (e) {
        debugPrint('[AURA PROACTIVE TEST] ⚠️ Android overlay pop up error: $e');
      }
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      await AuraBarMultiWindowService.instance.showOrCreateBar(
        state: BarState.proactive,
        muted: AuraBarBrain.instance.isMuted,
      );
    }
  }

  Future<void> _debugForceProactiveCycle() async {
    _debugCycleCount++;
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    debugPrint('');
    debugPrint(
      '┌──────────────────────────────────────────────────────────────┐',
    );
    debugPrint(
      '│ [AURA PROACTIVE TEST] 🔄 Triggering 60s cycle #$_debugCycleCount',
    );
    debugPrint('│ Time: $timestamp | State: Active');
    debugPrint('│ Platform: ${Platform.operatingSystem}');
    debugPrint(
      '└──────────────────────────────────────────────────────────────┘',
    );

    final stopwatch = Stopwatch()..start();

    // Step 0: Force-surface overlay window
    debugPrint('[AURA PROACTIVE TEST] 🪟 Forcing overlay to surface...');
    final overlayStopwatch = Stopwatch()..start();
    await _forceOverlayPopUp();
    debugPrint(
      '[AURA PROACTIVE TEST] ✅ Overlay forced in ${overlayStopwatch.elapsedMilliseconds}ms',
    );
    overlayStopwatch.stop();

    // Step 1: Force-call Rust FFI auraCheckProactive()
    debugPrint(
      '[AURA PROACTIVE TEST] ⚡ Calling auraCheckProactive() via Rust FFI...',
    );
    String rustLabel = '';
    final ffiStopwatch = Stopwatch()..start();
    try {
      rustLabel = await auraCheckProactive();
      debugPrint(
        '[AURA PROACTIVE TEST] ✅ auraCheckProactive() returned: "${rustLabel.isEmpty ? "(empty)" : rustLabel}" in ${ffiStopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint(
        '[AURA PROACTIVE TEST] ⚠️  auraCheckProactive() error: $e after ${ffiStopwatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        '[AURA PROACTIVE TEST] 📌 Falling back to debug_test_trigger label',
      );
    }
    ffiStopwatch.stop();

    // Step 2: Use the Rust label if non-empty, otherwise use a rotating debug trigger
    final triggerLabel = rustLabel.isNotEmpty
        ? rustLabel
        : _debugRotatingLabel();

    debugPrint('[AURA PROACTIVE TEST] 🎯 Dispatching trigger: "$triggerLabel"');
    debugPrint(
      '[AURA PROACTIVE TEST] 📡 Handing off to AuraBarBrain.handleProactiveTrigger()...',
    );

    // Step 3: Force the trigger — bypass cooldown by NOT setting _lastActivation check
    final dispatchStopwatch = Stopwatch()..start();
    try {
      await AuraBarBrain.instance.handleProactiveTrigger(triggerLabel);
      debugPrint(
        '[AURA PROACTIVE TEST] ✅ Proactive trigger "$triggerLabel" dispatched successfully in ${dispatchStopwatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        '[AURA PROACTIVE TEST] 🔊 TTS pipeline should now be speaking...',
      );
    } catch (e) {
      debugPrint(
        '[AURA PROACTIVE TEST] ❌ Error during proactive trigger: $e after ${dispatchStopwatch.elapsedMilliseconds}ms',
      );
    }
    dispatchStopwatch.stop();
    stopwatch.stop();

    debugPrint(
      '[AURA PROACTIVE TEST] ── Cycle #$_debugCycleCount complete. Total time: ${stopwatch.elapsedMilliseconds}ms. Next in 60s ──',
    );
    debugPrint('');
  }

  /// Returns a rotating debug trigger label for test variety, wrapped in the
  /// `{id,label,type}` JSON shape so it flows through the same plumbing as
  /// production triggers. Debug ids are <= -10 to stay clear of clock/idle ids.
  String _debugRotatingLabel() {
    const labels = [
      'morning_greeting',
      'afternoon_checkin',
      'evening_winddown',
      'debug_test_proactive',
    ];
    final label = labels[(_debugCycleCount - 1) % labels.length];
    final id = -10 - ((_debugCycleCount - 1) % labels.length);
    return _wrapTrigger(id, label, 'debug');
  }
}
