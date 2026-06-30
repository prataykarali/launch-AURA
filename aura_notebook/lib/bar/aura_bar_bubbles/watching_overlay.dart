// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class WatchingOverlay extends StatefulWidget {
  final String message;
  const WatchingOverlay({required this.message});

  @override
  State<WatchingOverlay> createState() => _WatchingOverlayState();
}

class _WatchingOverlayState extends State<WatchingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eyeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _eyeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _eyeCtrl, curve: Curves.easeInOut);
    _glowAnim = CurvedAnimation(parent: _eyeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _eyeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final t = _pulseAnim.value;
        return Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF001A1F).withOpacity(0.92),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF00BCD4).withOpacity(0.35),
                const Color(0xFF00E5FF).withOpacity(0.85),
                t,
              )!,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.12 + 0.22 * t),
                blurRadius: 20 + 14 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1.0 + 0.14 * t,
                child: Icon(
                  Icons.visibility_rounded,
                  size: 16,
                  color: Color.lerp(
                    const Color(0xFF00BCD4),
                    const Color(0xFFFFFFFF),
                    t * 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [
                      Color.lerp(
                        const Color(0xFF00E5FF),
                        const Color(0xFFFFFFFF),
                        t * 0.35,
                      )!,
                      const Color(0xFF26C6DA),
                    ],
                  ).createShader(b),
                  child: Text(
                    widget.message.isNotEmpty
                        ? widget.message
                        : 'AURA is watching 👁️',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
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
