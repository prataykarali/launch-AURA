// ── dark_card.dart ─────────────────────────────────────────────────────────────
// Place at: lib/screens/detail_widgets/dark_card.dart

import 'package:flutter/material.dart';

class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const DarkCard({super.key, required this.child,
    this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF161625),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: child,
  );
}

class CardTitle extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  const CardTitle(this.title, this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 14, color: color),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 14,
        fontWeight: FontWeight.w700)),
  ]);
}