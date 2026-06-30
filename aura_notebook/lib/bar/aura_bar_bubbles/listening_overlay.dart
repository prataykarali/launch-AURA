// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class ListeningOverlay extends StatefulWidget {
  const ListeningOverlay();

  @override
  State<ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<ListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _ringAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final pulse = _pulseAnim.value;
        return Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0628).withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF67E8F9).withOpacity(0.4),
                const Color(0xFF38BDF8).withOpacity(0.9),
                pulse,
              )!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF67E8F9).withOpacity(0.15 + 0.25 * pulse),
                blurRadius: 18 + 10 * pulse,
                spreadRadius: 1 + 2 * pulse,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: 1.0 + 0.18 * pulse,
                child: Icon(
                  Icons.mic_rounded,
                  color: Color.lerp(
                    const Color(0xFF67E8F9),
                    const Color(0xFFFFFFFF),
                    pulse,
                  ),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Color.lerp(
                      const Color(0xFF67E8F9),
                      const Color(0xFFFFFFFF),
                      pulse * 0.4,
                    )!,
                    const Color(0xFF38BDF8),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Listening... Speak now 🎤',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
