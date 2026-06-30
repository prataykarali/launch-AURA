import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'package:aura_notebook/bar/bar_multi_window_service.dart';
import 'package:aura_notebook/screens/loading_screen.dart';
import 'package:aura_notebook/screens/option_screen.dart';
import 'package:aura_notebook/services/android_overlay_service.dart';
import 'package:aura_notebook/services/bar_brain.dart';
import 'package:aura_notebook/services/proactive_scheduler.dart';
import 'package:aura_notebook/services/tts_service.dart';

class AuraRoot extends StatefulWidget {
  const AuraRoot({super.key});

  @override
  State<AuraRoot> createState() => _AuraRootState();
}

class _AuraRootState extends State<AuraRoot> {
  bool _loaded = false;
  bool _barStarted = false;

  @override
  void initState() {
    super.initState();
    // _performManualStorageReset removed — it truncated .memory.db files in
    // the models directory on first launch, destroying the GGUF KV cache.
    // Memory is now managed durably via the Rust MemoryStore (WAL SQLite at
    // ~/.local/share/aura_notebook/aura_memory.db), which persists across
    // app restarts with no truncation.
    // Show the bar EARLY so the user sees it within ~1s, in parallel with the
    // engine load. The original behaviour gated the overlay behind engine-ready
    // (after the ~697MB GGUF + 110MB ONNX spun up), and Samsung killed the
    // foreground service during that heavy CPU phase — so on Android the bar
    // effectively never appeared (no AURA_OVERLAY lines in logcat at all).
    //
    // Desktop starts its own bar window via _startBarWindow() below. Android's
    // overlay is requested here immediately; the bar shows its idle state and
    // any tap that needs the engine (mic / text submit) is guarded by
    // AuraBarBrain.engineReady and shows a "warming up" hint until ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBarWindow();
      if (Platform.isAndroid && !_barStarted) {
        _barStarted = true;
        unawaited(
          AndroidOverlayService.showBar(muted: AuraBarBrain.instance.isMuted),
        );
      }
    });

    if (Platform.isAndroid) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        debugPrint(
          'AURA_MAIN: overlay IPC raw event=${event.runtimeType}: $event',
        );
        if (event is String) {
          try {
            final data = jsonDecode(event);
            final action = data['action'];
            debugPrint(
              'AURA_MAIN: received overlay IPC payload=$data action=$action',
            );
            if (action == 'mic_tap') {
              debugPrint('AURA_MAIN: dispatching mic_tap to AuraBarBrain');
              unawaited(AuraBarBrain.instance.handleMicTap());
            } else if (action == 'speaker_tap') {
              unawaited(
                AuraBarBrain.instance.speakResponse(
                  AuraBarBrain.instance.currentResponse,
                ),
              );
            } else if (data['action'] == 'ask_tap') {
              // Android owns the text field inside the overlay process. Tapping
              // the ask/WHY affordance should focus that overlay field; opening
              // the full app here made proactive prompts look like redirects.
              debugPrint('AURA_MAIN: ask_tap handled by overlay focus');
            } else if (data['action'] == 'volume_toggle') {
              debugPrint(
                'AURA_MAIN: volume_toggle received, current isMuted=${AuraBarBrain.instance.isMuted}',
              );
              AuraBarBrain.instance.toggleVolume();
              final newMuted = AuraBarBrain.instance.isMuted;
              debugPrint(
                'AURA_MAIN: after toggleVolume, new isMuted=$newMuted',
              );
              // Push the authoritative mute state back to the Android overlay
              // so its _isMuted mirror re-syncs from the main process, not
              // just from its own optimistic local toggle. This closes the
              // drift where the overlay icon and the real audio mute state
              // disagreed after a tap.
              unawaited(
                AndroidOverlayService.updateState(
                  AuraBarBrain.instance.currentState,
                  muted: newMuted,
                ),
              );
            } else if (data['action'] == 'submit_text') {
              final text = data['text']?.toString() ?? '';
              if (text.isNotEmpty) {
                unawaited(AuraBarBrain.instance.processUserPrompt(text));
              }
            } else if (data['action'] == 'stop_tts') {
              AuraTTSService.instance.setPlaybackSuppressed(true);
              unawaited(AuraBarBrain.instance.cancelCurrentOps());
            }
          } catch (e, st) {
            debugPrint('AURA_MAIN: error parsing overlay event: $e\n$st');
          }
        } else {
          debugPrint('AURA_MAIN: ignored non-string overlay IPC event');
        }
      });
    }
  }

  Future<void> _startBarWindow() async {
    if (_barStarted) return;
    // Desktop only: spin up the native multi-window bar. Android's overlay is
    // launched above in initState (AndroidOverlayService.showBar) so it appears
    // immediately rather than waiting for the engine to load.
    if (Platform.isAndroid) return;
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return;
    _barStarted = true;
    unawaited(AuraBarMultiWindowService.instance.showOrCreateBar());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return LoadingScreen(
        onDone: () {
          setState(() {
            _loaded = true;
          });
          // Engine finished loading + warmup: mark it ready so the early bar's
          // guarded taps (mic / text submit) stop showing the "warming up"
          // hint and actually run inference. Route through setEngineReady() so
          // any prompt submitted while the engine was loading is flushed.
          AuraBarBrain.instance.setEngineReady();
          ProactiveScheduler.instance.start();
          // Wake-word (passive listening) disabled for now — push-to-talk via
          // the mic button still works (handleMicTap is independent of this).
          // Re-enable by uncommenting when STT is rebuilt for ambient listening.
          // AuraBarBrain.instance.startWakeWordListener();
        },
      );
    }
    return const OptionScreen();
  }
}
