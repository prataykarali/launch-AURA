import 'package:flutter/material.dart';
import 'stat_chip.dart';

class StatsBar extends StatelessWidget {
  final String mainLabel;
  final String dateLabel;
  final Color dateColor;

  const StatsBar({
    super.key,
    required this.mainLabel,
    required this.dateLabel,
    required this.dateColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        StatChip(
          icon: Icons.bookmark_outline_rounded,
          label: mainLabel,
          color: Colors.indigo.shade300,
        ),
        const SizedBox(width: 12),
        StatChip(
          icon: Icons.calendar_today_outlined,
          label: dateLabel,
          color: dateColor,
        ),
        const Spacer(),
        Text(
          'SQLite ✓',
          style: TextStyle(
            color: Colors.green.shade400,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
