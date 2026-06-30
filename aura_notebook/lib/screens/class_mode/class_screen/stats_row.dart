part of 'class_screen.dart';

class _StatsRow extends StatelessWidget {
  final List<ClassData> classes;
  const _StatsRow({required this.classes});

  @override
  Widget build(BuildContext context) {
    final s = classes.fold(0, (a, c) => a + c.students);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _Chip(
            Icons.class_rounded,
            '${classes.length} Classes',
            _classPrimary,
          ),
          const SizedBox(width: 10),
          _Chip(Icons.people_rounded, '$s Students', _classTeal),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.16),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.white30,
        letterSpacing: 2.0,
      ),
    ),
  );
}
