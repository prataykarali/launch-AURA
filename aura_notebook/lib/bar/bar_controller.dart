import 'package:flutter/material.dart';
import 'aura_bar.dart';

class AuraBarController {
  OverlayEntry? entry;

  void mount(BuildContext context) {
    final overlay = Overlay.of(context);
    _insert(overlay);
  }

  void mountOnOverlay(OverlayState overlay) {
    _insert(overlay);
  }

  void _insert(OverlayState overlay) {
    entry = OverlayEntry(builder: (_) => _AuraBarPositioned(controller: this));
    overlay.insert(entry!);
  }

  void remove() {
    entry?.remove();
    entry = null;
  }

  final visibleNotifier = ValueNotifier<bool>(false);
  final stateNotifier = ValueNotifier<BarState>(BarState.idle);
  final messageNotifier = ValueNotifier<String?>(null);

  void show() => visibleNotifier.value = true;
  void hide() => visibleNotifier.value = false;

  void setBarState(BarState state, {String? proactiveMessage}) {
    stateNotifier.value = state;
    messageNotifier.value = proactiveMessage;
  }

  void dispose() {
    remove();
    visibleNotifier.dispose();
    stateNotifier.dispose();
    messageNotifier.dispose();
  }
}

class _AuraBarPositioned extends StatelessWidget {
  final AuraBarController controller;
  const _AuraBarPositioned({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.visibleNotifier,
      builder: (_, visible, __) {
        if (!visible) return const SizedBox.shrink();
        return Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: ValueListenableBuilder<BarState>(
              valueListenable: controller.stateNotifier,
              builder: (_, state, __) => ValueListenableBuilder<String?>(
                valueListenable: controller.messageNotifier,
                builder: (_, msg, __) => AuraBar(
                  state: state,
                  proactiveMessage: msg,
                  onCloseTap: controller.hide,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
