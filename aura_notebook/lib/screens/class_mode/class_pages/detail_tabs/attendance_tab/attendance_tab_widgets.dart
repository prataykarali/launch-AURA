part of 'attendance_tab.dart';

// ── Attendance tile ───────────────────────────────────────────────────────────
class _AttendanceTile extends StatelessWidget {
  final StudentModel      student;
  final AttendanceStatus  status;
  final Color             accent;
  final void Function(AttendanceStatus) onChanged;

  const _AttendanceTile({required this.student, required this.status,
    required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Row(children: [
      CircleAvatar(radius: 16, backgroundColor: accent.withOpacity(0.15),
          child: Text(student.name[0], style: TextStyle(
              color: accent, fontWeight: FontWeight.w800))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.name, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600)),
            Text(student.roll, style: TextStyle(
                color: Colors.white.withOpacity(0.33), fontSize: 11)),
          ])),
      // P / L / A buttons
      Row(children: [
        _SBtn(AttendanceStatus.present, 'P', Colors.greenAccent, status,
                () => onChanged(AttendanceStatus.present)),
        const SizedBox(width: 6),
        _SBtn(AttendanceStatus.late,    'L', Colors.orange,      status,
                () => onChanged(AttendanceStatus.late)),
        const SizedBox(width: 6),
        _SBtn(AttendanceStatus.absent,  'A', Colors.redAccent,   status,
                () => onChanged(AttendanceStatus.absent)),
      ]),
    ]),
  );
}

class _SBtn extends StatelessWidget {
  final AttendanceStatus target, current;
  final String label; final Color color; final VoidCallback onTap;
  const _SBtn(this.target, this.label, this.color, this.current, this.onTap);
  bool get _active => target == current;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 32, height: 32,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _active ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
              color: _active ? color : Colors.white.withOpacity(0.15),
              width: _active ? 1.5 : 1)),
      child: Center(child: Text(label, style: TextStyle(
          color: _active ? color : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w800))),
    ),
  );
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String l; final Color c; final bool sel; final VoidCallback t;
  const _TabBtn(this.l, this.c, this.sel, this.t);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.15) : const Color(0xFF1E1E32),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? c.withOpacity(0.4)
              : Colors.white.withOpacity(0.08))),
      child: Text(l, style: TextStyle(
          color: sel ? c : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}

class _StatBadge extends StatelessWidget {
  final String v, l; final Color c;
  const _StatBadge(this.v, this.l, this.c);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
        Text(v, style: TextStyle(color: c, fontSize: 13,
            fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3),
            fontSize: 9)),
      ]);
}

class _SummaryNum extends StatelessWidget {
  final String v, l; final Color c;
  const _SummaryNum(this.v, this.l, this.c);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 20,
        fontWeight: FontWeight.w900)),
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.35),
        fontSize: 10)),
  ]);
}
