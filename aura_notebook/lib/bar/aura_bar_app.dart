import 'package:flutter/material.dart';

import 'bar_root_widget.dart';
import 'bar_state.dart';

import '../services/bar_brain.dart';

final barStateNotifier = ValueNotifier<BarState>(BarState.idle);
final barMessageNotifier = ValueNotifier<String?>(null);

// Legacy wrapper kept for older launch paths.
// It intentionally stays bar-only and never expands into the full app window.
class AuraBarApp extends StatelessWidget {
  const AuraBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BarState>(
      valueListenable: barStateNotifier,
      builder: (context, state, child) => ValueListenableBuilder<String?>(
        valueListenable: barMessageNotifier,
        builder: (context, message, child) => BarRootWidget(
          state: state,
          proactiveMessage: message,
          onSubmitText: (text) {
            AuraBarBrain.instance.processUserPrompt(text);
          },
        ),
      ),
    );
  }
}
