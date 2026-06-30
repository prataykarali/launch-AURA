import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'bar_state.dart';

/// Single volume mute/unmute toggle button. Shows `volume_off_rounded` when
/// muted, `volume_up_rounded` when unmuted. One tap toggles between the two.
/// Touch target ≥ 44 px for reliable tap detection on mobile.
class VolumeToggleButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback? onTap;
  const VolumeToggleButton({super.key, required this.isMuted, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final btnSize = isPhone ? 32.0 : 30.0;
    final iconSize = isPhone ? 16.0 : 14.0;
    final colors = BarState.idle.waveColors;
    final icon = isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded;
    final active = !isMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.first.withOpacity(active ? 0.32 : 0.14),
                  colors.last.withOpacity(active ? 0.16 : 0.06),
                ],
              ),
              border: Border.all(
                color: colors.first.withOpacity(active ? 0.60 : 0.30),
                width: 1.2,
              ),
            ),
            child: ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: colors).createShader(b),
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Speaker (TTS) button. Triggers AURA to SPEAK the current/last response via
/// the main window's speaker_tap handler (AuraBarBrain.speakResponse).
///
/// This is intentionally separate from VolumeToggleButton:
///   • VolumeToggleButton = mute / unmute the audio OUTPUT gain.
///   • SpeakerButton       = ask AURA to speak the response NOW.
/// Previously the ONLY audio control rendered in the pill was the mute toggle,
/// so the user had no manual way to trigger TTS — it only fired automatically on
/// generation. That made the "TTS button" look dead: it didn't exist. This
/// widget is the missing button.
///
/// `armed` = true when there is a response to speak (and TTS is available).
/// When not armed it renders faded and ignores taps so it doesn't look like a
/// broken control during idle/listening states.
class SpeakerButton extends StatelessWidget {
  final bool armed;
  final VoidCallback? onTap;
  const SpeakerButton({super.key, required this.armed, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final btnSize = isPhone ? 32.0 : 30.0;
    final iconSize = isPhone ? 16.0 : 14.0;
    final colors = BarState.idle.waveColors;
    const icon = Icons.record_voice_over_rounded;

    return GestureDetector(
      onTap: armed ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.first.withOpacity(armed ? 0.32 : 0.10),
                  colors.last.withOpacity(armed ? 0.16 : 0.04),
                ],
              ),
              border: Border.all(
                color: colors.first.withOpacity(armed ? 0.60 : 0.22),
                width: 1.2,
              ),
            ),
            child: ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: colors).createShader(b),
              child: Icon(
                icon,
                color: armed ? Colors.white : Colors.white38,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MicButton extends StatelessWidget {
  final BarState state;
  final VoidCallback? onTap;
  const MicButton({super.key, required this.state, this.onTap});

  IconData get _icon => switch (state) {
    BarState.idle => Icons.mic_none_rounded,
    BarState.listening => Icons.mic_rounded,
    BarState.speaking => Icons.mic_off_rounded,
    BarState.processing => Icons.hourglass_empty_rounded,
    BarState.proactive => Icons.notifications_active_rounded,
    BarState.learning => Icons.insights_rounded,
    BarState.wakeListening => Icons.mic_rounded,
    BarState.watching => Icons.mic_none_rounded,
    BarState.warning => Icons.warning_amber_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final btnSize = isPhone ? 36.0 : 32.0;
    final iconSize = isPhone ? 20.0 : 17.0;
    final colors = state.waveColors;
    final isActive = state.isActive;

    Widget btn = Container(
      width: btnSize,
      height: btnSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.first.withOpacity(0.28),
            colors.last.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: colors.first.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (b) => LinearGradient(colors: colors).createShader(b),
        child: Icon(_icon, color: Colors.white, size: iconSize),
      ),
    );

    if (isActive) {
      btn = btn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.14,
            duration: 850.ms,
            curve: Curves.easeInOut,
          );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: btnSize + 8,
        height: btnSize + 8,
        child: Center(child: btn),
      ),
    );
  }
}
