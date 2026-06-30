import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../bar_root_widget.dart';
import '../bar_state.dart';
import '../bar_multi_window_service.dart';
import 'bar_window_app_controller.dart';
import 'bar_window_app_host.dart';

class BarWindowApp extends StatefulWidget {
  final WindowController? controller;

  const BarWindowApp({super.key, required this.controller});

  @override
  State<BarWindowApp> createState() => _BarWindowAppState();
}

class _BarWindowAppState extends State<BarWindowApp>
    with WindowListener
    implements BarWindowAppHost {
  late final BarWindowAppController _controller;

  @override
  WindowController? get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller = BarWindowAppController(this);
    _controller.init();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.showAndFocus());
  }

  @override
  void onWindowClose() async {
    await _controller.close();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.controller?.setWindowMethodHandler(null);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _controller.onPointerDown,
      onPointerMove: _controller.onPointerMove,
      onPointerUp: _controller.onPointerUp,
      onPointerCancel: _controller.onPointerCancel,
      child: ValueListenableBuilder<BarState>(
        valueListenable: _controller.barState,
        builder: (context, state, child) => ValueListenableBuilder<String?>(
          valueListenable: _controller.message,
          builder: (context, message, child) => ValueListenableBuilder<bool>(
            valueListenable: _controller.hasResponse,
            builder: (context, hasResponse, child) => ValueListenableBuilder<bool>(
              // Reactive mute mirror so the volume icon updates instantly on
              // both local tap and when the main window pushes the real state.
              valueListenable: _controller.isMutedNotifier,
              builder: (context, muted, child) {
                return BarRootWidget(
                  state: state,
                  proactiveMessage: message,
                  // All voice/chat actions are OWNED by the main window (engine +
                  // ready AuraBarBrain live there). Forward via IPC instead of
                  // calling a local AuraBarBrain whose engineReady is never true.
                  onMicTap: _controller.onMicTap,
                  onAskTap: _controller.onAskTap,
                  onSpeakerTap: _controller.onSpeakerTap,
                  onVolumeToggle: _controller.onVolumeToggle,
                  isMuted: muted,
                  hasResponse: hasResponse,
                  onSubmitText: _controller.handleSubmitText,
                  onCloseTap: () async {
                    debugPrint('BarWindow: close button tapped');
                    await AuraBarMultiWindowService.instance.closeBar();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
