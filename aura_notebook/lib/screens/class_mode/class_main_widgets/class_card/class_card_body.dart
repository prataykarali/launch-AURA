part of 'class_card.dart';

class _Body extends StatelessWidget {
  final ClassData d;
  const _Body({required this.d});

  String get _initial {
    final t = d.teacher.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(' ');
    final last = parts.last;
    if (last.isEmpty) return '?';
    return last.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _cardSurface,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats strip
        Container(
          color: _cardSurfaceHigh,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _Stat(
                Icons.people_outline_rounded,
                '${d.students} students',
                d.accent,
              ),
              const SizedBox(width: 16),
              _Stat(Icons.assignment_outlined, 'Assignments', d.accent),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: d.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: d.accent.withOpacity(0.3)),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    color: d.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Teacher row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [d.accent, d.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.teacher,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Class Teacher',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Open button
              GestureDetector(
                onTap: () {}, // handled by card tap
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: d.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: d.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          color: d.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: d.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Divider + quick actions
        Divider(height: 1, color: _cardLine),
        SizedBox(
          height: 54,
          child: Row(
            children: [
              _QA(Icons.menu_book_outlined, 'Lessons', d.accent),
              VerticalDivider(width: 1, color: _cardLine),
              _QA(Icons.people_outline_rounded, 'Students', d.accent),
              VerticalDivider(width: 1, color: _cardLine),
              _QA(Icons.assignment_outlined, 'Tasks', d.accent),
              VerticalDivider(width: 1, color: _cardLine),
              _QA(Icons.campaign_outlined, 'Stream', d.accent),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData i;
  final String l;
  final Color c;
  const _Stat(this.i, this.l, this.c);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 13, color: c.withOpacity(0.7)),
      const SizedBox(width: 5),
      Text(
        l,
        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
      ),
    ],
  );
}

class _QA extends StatelessWidget {
  final IconData i;
  final String l;
  final Color c;
  const _QA(this.i, this.l, this.c);
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 16, color: c),
            const SizedBox(height: 3),
            Text(
              l,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
