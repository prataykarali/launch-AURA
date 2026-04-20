// Place at: lib/screens/detail_widgets/section_label.dart
import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
    child: Text(text,
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: Colors.white.withOpacity(0.28),
        letterSpacing: 1.8,
      ),
    ),
  );
}