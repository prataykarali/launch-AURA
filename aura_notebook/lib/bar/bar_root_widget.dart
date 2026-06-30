import 'package:flutter/material.dart';
import 'dart:io';
import 'aura_bar.dart';

// This is the entire app widget tree when in bar-only mode.
// Renders nothing except the transparent bar at bottom.
class BarRootWidget extends StatelessWidget {
  final BarState state;
  final String? proactiveMessage;
  final VoidCallback? onMicTap;
  final VoidCallback? onSpeakerTap;
  final VoidCallback? onAskTap;
  final ValueChanged<String>? onSubmitText;
  final VoidCallback? onVolumeToggle;
  final VoidCallback? onCloseTap;
  final ValueChanged<bool>? onFocusChanged;
  final bool isMuted;

  /// Whether AURA currently has a response that can be spoken via the Speaker
  /// button. The Speaker (TTS) button renders faded + non-interactive until
  /// this is true, so it never looks "broken" during idle/listening states.
  final bool hasResponse;

  const BarRootWidget({
    super.key,
    required this.state,
    this.proactiveMessage,
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
  Widget build(BuildContext context) {
    // On Android the overlay window is positioned at OverlayAlignment.bottomCenter
    // but does NOT include system navigation bar insets automatically. Without
    // SafeArea (or explicit bottom padding) the pill renders *behind* the nav bar.
    // SafeArea(bottom: true) inserts the correct inset (typically 32–48dp) so the
    // pill always floats visibly above the navigation bar on all Android devices.
    //
    // Background glitch fix: every container in the chain must be fully
    // transparent. The MaterialApp theme sets scaffoldBackgroundColor to
    // transparent, and the Scaffold.backgroundColor is also explicit transparent.
    // Any opaque remnant causes a black rectangle on Samsung OLED screens.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        // Ensure dialogs / surfaces are also transparent so no black bleeds through
        dialogBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        cardColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: !Platform.isAndroid,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                // Extra 4dp above the SafeArea inset so the pill has a small gap
                // from the navigation bar / screen edge.
                padding: EdgeInsets.only(bottom: Platform.isAndroid ? 0 : 4),
                child: AuraBar(
                  state: state,
                  proactiveMessage: proactiveMessage,
                  onMicTap: onMicTap,
                  onSpeakerTap: onSpeakerTap,
                  onAskTap: onAskTap,
                  onSubmitText: onSubmitText,
                  onVolumeToggle: onVolumeToggle,
                  onCloseTap: onCloseTap,
                  onFocusChanged: onFocusChanged,
                  isMuted: isMuted,
                  hasResponse: hasResponse,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
