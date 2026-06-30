part of 'aura_bar_lib.dart';

Widget _buildAuraBar(_AuraBarState state, BuildContext context) {
  final size = MediaQuery.of(context).size;
  final screenW = size.width;
  final isPhone = screenW < 600;
  final isFloatingBarWindow = !isPhone && size.height <= 250;
  final maxW = isPhone || isFloatingBarWindow ? 760.0 : 680.0;
  final hPad = isFloatingBarWindow ? 8.0 : (isPhone ? 12.0 : 20.0);

  final pillH = isPhone ? 70.0 : (isFloatingBarWindow ? 66.0 : 62.0);

  final bubble = _buildBubble(state);

  return FadeTransition(
    opacity: state._fadeAnim,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (state._focusNode.hasFocus) {
          state._focusNode.unfocus();
        }
      },
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: Padding(
              padding: EdgeInsets.only(
                left: hPad,
                right: hPad,
                bottom: isPhone ? 24.0 : hPad,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        [state._rainbowCtrl, state._glowCtrl],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF06061A),
                                  Color(0xFF0E0628),
                                  Color(0xFF060E1A),
                                ],
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: state._orbCtrl,
                            builder: (context, _) {
                              final orb1Phase = state._orbCtrl.value * 2 * pi;
                              final orb2Phase =
                                  pi + state._orbCtrl.value * 2 * pi * 0.7;
                              return NebulaLayer(
                                orb1Phase: orb1Phase,
                                orb2Phase: orb2Phase,
                                colors: state.widget.state.waveColors,
                              );
                            },
                          ),
                          const PillStarfield(),
                          RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  MicButton(
                                    state: state.widget.state,
                                    onTap: state.widget.onMicTap,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: (state.widget.state ==
                                                BarState.idle ||
                                            state.widget.state ==
                                                BarState.proactive ||
                                            state.widget.state ==
                                                BarState.wakeListening ||
                                            state.widget.state ==
                                                BarState.watching)
                                        ? _buildTypeBar(state)
                                        : AuraWaveform(
                                            state: state.widget.state,
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  VolumeToggleButton(
                                    isMuted: state.widget.isMuted,
                                    onTap: state.widget.onVolumeToggle,
                                  ),
                                  if (state.widget.hasResponse &&
                                      !state.widget.isMuted) ...[
                                    const SizedBox(width: 8),
                                    SpeakerButton(
                                      armed: true,
                                      onTap: state.widget.onSpeakerTap,
                                    ),
                                  ],
                                  if (state.widget.onCloseTap != null) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: state.widget.onCloseTap,
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Center(
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white38,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 28,
                            right: 28,
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.28),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      builder: (_, child) => PillShell(
                        rainbowT: state._rainbowCtrl.value,
                        glowT: state._glowCtrl.value,
                        accentColor: state.widget.state.waveColors.first,
                        child: child!,
                      ),
                    ),
                  ),
                  if (bubble != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: pillH + 6),
                      child: bubble,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
