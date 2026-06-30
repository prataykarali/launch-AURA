import 'package:flutter/material.dart';

class StatBox extends StatelessWidget {
  final String v, l;
  final IconData i;
  final Color c;
  const StatBox(this.v, this.l, this.i, this.c, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: [
      Icon(i, size: 18, color: c),
      const SizedBox(height: 6),
      Text(v, style: TextStyle(color: c, fontSize: 18,
          fontWeight: FontWeight.w800)),
      Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3),
          fontSize: 9)),
    ]),
  );
}
