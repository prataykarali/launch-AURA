import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:aura_notebook/bar/bar_state.dart';
import 'package:aura_notebook/bar/bar_shell.dart';
import 'package:aura_notebook/bar/bar_particles.dart';
import 'package:aura_notebook/bar/bar_waveform.dart';
import 'package:aura_notebook/bar/bar_buttons.dart';
import 'package:aura_notebook/services/bar_brain.dart' hide kBarMaxChars;
import 'package:aura_notebook/bar/aura_bar_bubbles/proactive_bubble.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/learning_bubble.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/processing_overlay.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/warning_bubble.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/ask_anything_overlay.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/wake_listening_overlay.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/listening_overlay.dart';
import 'package:aura_notebook/bar/aura_bar_bubbles/watching_overlay.dart';
import 'constants.dart';

part 'build.dart';
part 'type_bar.dart';
part 'bubble_builder.dart';
part 'typewriter.dart';

class AuraBar extends StatefulWidget {
  final BarState state;
  final String? proactiveMessage;
  final String? learningMessage;
  final VoidCallback? onMicTap;
  final VoidCallback? onSpeakerTap;
  final VoidCallback? onAskTap;
  final ValueChanged<String>? onSubmitText;
  final VoidCallback? onVolumeToggle;
  final VoidCallback? onCloseTap;
  final ValueChanged<bool>? onFocusChanged;
  final bool isMuted;
  final bool hasResponse;

  const AuraBar({
    super.key,
    this.state = BarState.idle,
    this.proactiveMessage,
    this.learningMessage,
    this.onMicTap,
    this.onSpeakerTap,
    this.onAskTap,
    this.onSubmitText,
    this.onVolumeToggle,
    this.onCloseTap,
    this.onFocusChanged,
    this.isMuted = false,
    this.hasResponse = false,
  });

  @override
  State<AuraBar> createState() => _AuraBarState();
}

class _AuraBarState extends State<AuraBar> with TickerProviderStateMixin {
  String _displayedMessage = '';
  Timer? _typewriterTimer;
  final List<String> _typewriterQueue = [];

  // ── Idle auto-clear timer (Fix 6) ──────────────────────────────────────
  // Clears the text field after 2.5 minutes of inactivity so stale text
  // doesn't linger in the bar. Reset on every keystroke.
  Timer? _idleClearTimer;

  late final AnimationController _fadeCtrl;
  late final AnimationController _rainbowCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _orbCtrl;
  late final AnimationController _bubbleCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _bubbleAnim;

  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  // Send-button visibility notifier — avoids per-keystroke setState.
  late ValueNotifier<bool> _barHasTextNotifier;
  bool _barHasText = false;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      const MethodChannel('x-slayer/overlay').setMethodCallHandler((call) async {
        if (call.method == 'focusChanged') {
          final hasFocus = call.arguments as bool;
          if (!hasFocus && mounted && _focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        }
      });
    }

    _textCtrl = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() async {
      final hasFocus = _focusNode.hasFocus;
      if (Platform.isAndroid) {
        try {
          await FlutterOverlayWindow.updateFlag(
            hasFocus ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag,
          );
          if (!hasFocus) {
            await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          }
        } catch (e) {
          debugPrint(
            'AURA_BAR: updateFlag(${hasFocus ? 'focusPointer' : 'defaultFlag'}) failed: $e',
          );
        }
      }
      if (!Platform.isAndroid) {
        if (hasFocus) {
          AuraBarBrain.instance.stopWakeWordListener();
        } else {
          AuraBarBrain.instance.startWakeWordListener();
        }
      }
      widget.onFocusChanged?.call(hasFocus);

      if (Platform.isAndroid && hasFocus) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted && _focusNode.hasFocus) {
          await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        }
      }
    });
    _barHasTextNotifier = ValueNotifier<bool>(false);
    _barHasText = false;
    _textCtrl.addListener(_onBarTextChanged);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _rainbowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bubbleAnim = CurvedAnimation(
      parent: _bubbleCtrl,
      curve: Curves.easeOutBack,
    );
    if (widget.proactiveMessage != null || widget.learningMessage != null) {
      _bubbleCtrl.value = 1.0;
      final initialMsg = widget.proactiveMessage ?? widget.learningMessage;
      if (initialMsg != null) {
        _startTypewriter(initialMsg);
      }
    }
  }

  void _onBarTextChanged() {
    final h = _textCtrl.text.trim().isNotEmpty;
    if (h != _barHasText) {
      _barHasText = h;
      _barHasTextNotifier.value = h;
    }
    _resetIdleClearTimer();
  }

  void _resetIdleClearTimer() {
    _idleClearTimer?.cancel();
    _idleClearTimer = Timer(const Duration(minutes: 2, seconds: 30), () {
      if (mounted && _textCtrl.text.trim().isNotEmpty) {
        _textCtrl.clear();
        _focusNode.unfocus();
        if (_barHasText) {
          _barHasText = false;
          _barHasTextNotifier.value = false;
        }
      }
    });
  }

  @override
  void didUpdateWidget(AuraBar old) {
    super.didUpdateWidget(old);
    final newMsg = widget.proactiveMessage ?? widget.learningMessage;
    final oldMsg = old.proactiveMessage ?? old.learningMessage;

    if (newMsg != null) {
      _bubbleCtrl.forward();
      if (newMsg != oldMsg) {
        _startTypewriter(newMsg);
      }
    } else {
      _bubbleCtrl.reverse();
      _displayedMessage = '';
      _typewriterQueue.clear();
    }
  }

  void _startTypewriter(String fullText) {
    _runTypewriter(this, fullText, (fn) => setState(fn));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _barHasTextNotifier.dispose();
    _idleClearTimer?.cancel();
    _fadeCtrl.dispose();
    _rainbowCtrl.dispose();
    _glowCtrl.dispose();
    _orbCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildAuraBar(this, context);
}
