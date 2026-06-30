import 'dart:math';
import 'package:flutter/material.dart';

class PillShell extends StatelessWidget {
  final double rainbowT;
  final double glowT;
  final Color accentColor;
  final Widget child;
  const PillShell({
    super.key,
    required this.rainbowT,
    required this.glowT,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive: taller on phone, slimmer on laptop
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final isPhone = screenW < 600;
    final isFloatingBarWindow = !isPhone && size.height <= 250;
    final pillH = isPhone ? 70.0 : (isFloatingBarWindow ? 66.0 : 62.0);

    final colors = List.generate(7, (i) {
      final hue = ((rainbowT + i / 7) % 1.0) * 360;
      return HSVColor.fromAHSV(1.0, hue, 0.85, 1.0).toColor();
    });
    final glowColor = HSVColor.fromAHSV(
      0.25 + glowT * 0.3,
      (rainbowT * 360) % 360,
      0.75,
      1.0,
    ).toColor();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(52),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 28 + glowT * 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 50,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Container(
        height: pillH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(52),
          gradient: SweepGradient(
            colors: [...colors, colors.first],
            transform: GradientRotation(rainbowT * 2 * pi),
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: RepaintBoundary(
            child: child,
          ),
        ),
      ),
    );
  }
}
