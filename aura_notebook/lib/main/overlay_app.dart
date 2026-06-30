import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'package:aura_notebook/bar/bar_root_widget.dart';
import 'package:aura_notebook/bar/bar_state.dart';
import 'package:aura_notebook/services/stt_service.dart';

void runOverlay() {
  WidgetsFlutterBinding.ensureInitialized();
  AuraSTTService.isMainApp = false;
  runApp(const AuraOverlayApp());
}

class AuraOverlayApp extends StatefulWidget {
  const AuraOverlayApp({super.key});

  @override
  State<AuraOverlayApp> createState() => _AuraOverlayAppState();
}

class _AuraOverlayAppState extends State<AuraOverlayApp> {
  BarState _state = BarState.idle;
  String? _message;
  bool _hasResponse = false;
  // Local mute mirror for instant icon feedback. Toggled optimistically on
  // tap; the real audio muting happens in the main-app process via the
  // volume_toggle IPC action. The two flip on the same tap, so they stay
  // in sync.
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String) {
        try {
          final data = jsonDecode(event);
          debugPrint('AURA_OVERLAY: received IPC data=$data');
          if (data['action'] == 'update') {
            final stateName = data['state'];
            final msg = data['message'];
            // Main app may push the authoritative mute state alongside
            // state/message updates; honor it if present.
            final muted = data['muted'];
            debugPrint(
              'AURA_OVERLAY: update action, muted from main=$muted, current _isMuted=$_isMuted',
            );
            final nextState = BarState.values.firstWhere(
              (s) => s.name == stateName,
              orElse: () => BarState.idle,
            );
            setState(() {
              _state = nextState;
              _message = msg == null || msg.isEmpty ? null : msg;
              _hasResponse = _message != null && _message!.trim().isNotEmpty;
              if (muted is bool) {
                debugPrint(
                  'AURA_OVERLAY: syncing _isMuted from main: $_isMuted -> $muted',
                );
                _isMuted = muted;
              }
            });
          }
        } catch (e) {
          debugPrint('Error parsing overlay message: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BarRootWidget(
      state: _state,
      proactiveMessage: _message,
      isMuted: _isMuted,
      hasResponse: _hasResponse,
      onMicTap: () async {
        final payload = jsonEncode({'action': 'mic_tap'});
        debugPrint('AURA_OVERLAY: onMicTap entry');
        try {
          debugPrint('AURA_OVERLAY: sending IPC payload=$payload');
          await FlutterOverlayWindow.shareData(payload);
          debugPrint('AURA_OVERLAY: sent mic_tap IPC');
        } catch (e, st) {
          debugPrint('AURA_OVERLAY: mic_tap IPC error: $e\n$st');
        }
      },
      onSpeakerTap: () async {
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'speaker_tap'}),
        );
      },
      onAskTap: () async {
        await FlutterOverlayWindow.shareData(jsonEncode({'action': 'ask_tap'}));
      },
      onVolumeToggle: () async {
        // Optimistic local toggle for instant icon feedback.
        final newMuted = !_isMuted;
        debugPrint(
          'AURA_OVERLAY: onVolumeToggle, optimistic toggle _isMuted: $_isMuted -> $newMuted',
        );
        setState(() => _isMuted = newMuted);
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'volume_toggle'}),
        );
        debugPrint('AURA_OVERLAY: volume_toggle IPC sent');
      },
      onSubmitText: (text) async {
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'submit_text', 'text': text}),
        );
      },
      onCloseTap: () async {
        debugPrint('AURA_OVERLAY: close button tapped — closing overlay');
        // Stop any ongoing TTS playback before closing.
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'stop_tts'}),
        );
        await FlutterOverlayWindow.closeOverlay();
      },
      onFocusChanged: (hasFocus) async {
        debugPrint(
          'AURA_OVERLAY: text field ${hasFocus ? 'focused' : 'unfocused'}',
        );
      },
    );
  }
}
