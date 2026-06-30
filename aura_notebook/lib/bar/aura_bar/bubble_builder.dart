part of 'aura_bar_lib.dart';

Widget? _buildBubble(_AuraBarState state) {
  if (state.widget.state == BarState.learning) {
    return Center(
      child: ScaleTransition(
        scale: state._bubbleAnim,
        alignment: Alignment.bottomCenter,
        child: LearningBubble(message: state._displayedMessage),
      ),
    );
  }
  if (state.widget.state == BarState.watching) {
    return Center(
      child: ScaleTransition(
        scale: state._bubbleAnim,
        alignment: Alignment.bottomCenter,
        child: WatchingOverlay(
          message: state._displayedMessage.isNotEmpty
              ? state._displayedMessage
              : 'AURA is watching 👁️',
        ),
      ),
    );
  }
  if (state.widget.state == BarState.warning) {
    return Center(
      child: ScaleTransition(
        scale: state._bubbleAnim,
        alignment: Alignment.bottomCenter,
        child: WarningBubble(message: state._displayedMessage),
      ),
    );
  }
  if (state.widget.state == BarState.proactive ||
      state.widget.state == BarState.speaking) {
    return Center(
      child: ScaleTransition(
        scale: state._bubbleAnim,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () async {
            if (Platform.isAndroid) {
              try {
                await FlutterOverlayWindow.updateFlag(
                  OverlayFlag.focusPointer,
                );
                await Future<void>.delayed(const Duration(milliseconds: 60));
              } catch (e) {
                debugPrint('AURA_BAR: pre-focus updateFlag failed: $e');
              }
            }
            state.widget.onMicTap?.call();
          },
          child: ProactiveBubble(message: state._displayedMessage),
        ),
      ),
    );
  }
  if (state.widget.state == BarState.wakeListening) {
    return const Center(child: WakeListeningOverlay());
  }
  if (state.widget.state == BarState.listening) {
    return const Center(child: ListeningOverlay());
  }
  if (state.widget.state == BarState.processing) {
    return Center(
      child: ProcessingOverlay(
        message: state._displayedMessage.isNotEmpty
            ? state._displayedMessage
            : null,
      ),
    );
  }
  if (state.widget.state == BarState.idle) {
    return Center(
      child: AskAnythingOverlay(
        onTap: () async {
          if (Platform.isAndroid) {
            try {
              await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
              await Future<void>.delayed(const Duration(milliseconds: 60));
            } catch (e) {
              debugPrint('AURA_BAR: pre-focus updateFlag failed: $e');
            }
          }
          state._focusNode.requestFocus();
        },
      ),
    );
  }
  return null;
}
