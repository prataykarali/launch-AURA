import 'dart:math';
import 'package:flutter/material.dart';

// atmospheric_particles v1.0.0 has no named params — use pure painter instead
class _Star {
  double x, y, radius, opacity, speed, twinklePhase;
  _Star(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 0.4 + rng.nextDouble() * 1.4,
        opacity = 0.2 + rng.nextDouble() * 0.7,
        speed = 0.00005 + rng.nextDouble() * 0.00008,
        twinklePhase = rng.nextDouble() * 2 * pi;
}

class PillStarfield extends StatefulWidget {
  const PillStarfield({super.key});

  @override
  State<PillStarfield> createState() => _PillStarfieldState();
}

class _PillStarfieldState extends State<PillStarfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Random _rng = Random();
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(24, (_) => _Star(_rng));
    // Slower (18s vs 20s) — fewer repaints, still feels alive. Drives only
    // the CustomPaint below via _ctrl.value, NOT setState, so the parent bar
    // subtree is never rebuilt by this animation (the previous version called
    // setState 60×/sec and was a major cause of bar jerking).
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _StarfieldPainter(stars: _stars, t: _ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarfieldPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final x = ((s.x + s.speed * t * size.width) % 1.0) * size.width;
      final twinkle =
          (0.2 + sin(t * 2 * pi + s.twinklePhase) * 0.4 + 0.3).clamp(0.05, 1.0);
      paint.color = Colors.white.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.t != t;
}

class NebulaLayer extends StatelessWidget {
  final double orb1Phase, orb2Phase;
  final List<Color> colors;
  const NebulaLayer({
    super.key,
    required this.orb1Phase,
    required this.orb2Phase,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      return Stack(children: [
        Positioned(
          left: w * 0.1 + sin(orb1Phase) * w * 0.05,
          top: h * 0.05 + cos(orb1Phase) * h * 0.15,
          child: _Orb(size: w * 0.3, color: colors.first.withOpacity(0.16)),
        ),
        Positioned(
          right: w * 0.08 + sin(orb2Phase) * w * 0.04,
          top: cos(orb2Phase) * h * 0.1,
          child: _Orb(size: w * 0.25, color: colors.last.withOpacity(0.13)),
        ),
      ]);
    });
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );
}