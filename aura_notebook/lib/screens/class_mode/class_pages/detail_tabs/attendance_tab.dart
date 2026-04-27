import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';
import '../student_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttendanceTab — receives the shared List<StudentModel> from ClassDetailPage
// so it always shows exactly the same students as the Roster tab.
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceTab extends StatefulWidget {
  final ClassData          data;
  final List<StudentModel> students;   // ← shared list from ClassDetailPage

  const AttendanceTab({
    super.key,
    required this.data,
    required this.students,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {

  // date string (yyyy-MM-dd) → { studentName → status }
  final Map<String, Map<String, AttendanceStatus>> _records = {};

  DateTime _selectedDate = DateTime.now();
  String   _view         = 'Mark'; // 'Mark' | 'Summary'

  String get _dateKey {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // Gets or creates today's record, seeding new students as Present
  Map<String, AttendanceStatus> get _todayRecord {
    final rec = _records.putIfAbsent(_dateKey, () => {});
    // Add any students not yet in this record
    for (final s in widget.students) {
      rec.putIfAbsent(s.name, () => AttendanceStatus.present);
    }
    return rec;
  }

  void _setStatus(String name, AttendanceStatus st) {
    HapticFeedback.selectionClick();
    setState(() => _todayRecord[name] = st);
  }

  void _markAll(AttendanceStatus st) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final s in widget.students) _todayRecord[s.name] = st;
    });
  }

  double _pct(String name) {
    if (_records.isEmpty) return 100.0;
    int present = 0, total = 0;
    for (final rec in _records.values) {
      total++;
      if ((rec[name] ?? AttendanceStatus.present) ==
          AttendanceStatus.present) present++;
    }
    return total == 0 ? 100.0 : present / total * 100;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(children: [
      // ── Top bar ──────────────────────────────────────────────────────
      Container(
        color: const Color(0xFF0D0D18),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          _TabBtn('Mark',    d.accent,              _view == 'Mark',
                  () => setState(() => _view = 'Mark')),
          const SizedBox(width: 8),
          _TabBtn('Summary', const Color(0xFF26A69A), _view == 'Summary',
                  () => setState(() => _view = 'Summary')),
          const Spacer(),
          // Date picker
          GestureDetector(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate:   DateTime(2024),
                lastDate:    DateTime.now(),
                builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(primary: d.accent)),
                    child: child!),
              );
              if (p != null) setState(() => _selectedDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: d.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: d.color.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: d.accent),
                const SizedBox(width: 6),
                Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(color: d.accent, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),

      // ── Content ───────────────────────────────────────────────────────
      Expanded(
        child: widget.students.isEmpty
            ? _emptyNoStudents(d.accent)
            : _view == 'Mark'
            ? _buildMark(d)
            : _buildSummary(d),
      ),
    ]);
  }

  // ── Empty state when no students added yet ─────────────────────────────────
  Widget _emptyNoStudents(Color accent) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline_rounded, size: 52,
            color: accent.withOpacity(0.3)),
        const SizedBox(height: 14),
        const Text('No Students Enrolled',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Add students in the Students tab first.\nThey will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.35),
                fontSize: 13, height: 1.5)),
      ]),
    ),
  );

  // ── Mark attendance view ──────────────────────────────────────────────────
  Widget _buildMark(ClassData d) {
    final rec          = _todayRecord;
    final presentCount = rec.values
        .where((s) => s == AttendanceStatus.present).length;
    final absentCount  = rec.values
        .where((s) => s == AttendanceStatus.absent).length;
    final lateCount    = rec.values
        .where((s) => s == AttendanceStatus.late).length;

    return Column(children: [
      // Stats strip
      Container(
        color: const Color(0xFF0F0F1E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _StatBadge('${widget.students.length}', 'Total',   Colors.white54),
          const SizedBox(width: 12),
          _StatBadge('$presentCount', 'Present', Colors.greenAccent),
          const SizedBox(width: 12),
          _StatBadge('$lateCount',    'Late',    Colors.orange),
          const SizedBox(width: 12),
          _StatBadge('$absentCount',  'Absent',  Colors.redAccent),
          const Spacer(),
          GestureDetector(
            onTap: () => _markAll(AttendanceStatus.present),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.3))),
              child: const Text('All Present',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      // Student rows
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: widget.students.length,
          itemBuilder: (_, i) {
            final s  = widget.students[i];
            final st = rec[s.name] ?? AttendanceStatus.present;
            return _AttendanceTile(
              student: s, status: st, accent: d.accent,
              onChanged: (newSt) => _setStatus(s.name, newSt),
            );
          },
        ),
      ),
    ]);
  }

  // ── Summary view ──────────────────────────────────────────────────────────
  Widget _buildSummary(ClassData d) {
    final totalSessions = _records.length;
    final lowCount = widget.students
        .where((s) => _pct(s.name) < 75).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: const Color(0xFF161625),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryNum('$totalSessions',          'Sessions', d.accent),
              _SummaryNum('${widget.students.length}', 'Students', const Color(0xFF26A69A)),
              _SummaryNum('$lowCount',               'Below 75%', Colors.redAccent),
            ],
          ),
        ),
        // Per-student breakdown
        ...widget.students.map((s) {
          final pct = _pct(s.name);
          final col = pct >= 75 ? Colors.greenAccent : Colors.redAccent;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFF161625),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pct < 75
                    ? Colors.redAccent.withOpacity(0.25)
                    : Colors.white.withOpacity(0.06))),
            child: Column(children: [
              Row(children: [
                CircleAvatar(radius: 16, backgroundColor: col.withOpacity(0.15),
                    child: Text(s.name[0], style: TextStyle(
                        color: col, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(s.roll, style: TextStyle(
                      color: Colors.white.withOpacity(0.33), fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${pct.toInt()}%', style: TextStyle(
                      color: col, fontSize: 16, fontWeight: FontWeight.w900)),
                  if (pct < 75)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('⚠ Low',
                            style: TextStyle(color: Colors.redAccent,
                                fontSize: 9, fontWeight: FontWeight.w700))),
                ]),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.white.withOpacity(0.07),
                      valueColor: AlwaysStoppedAnimation(col),
                      minHeight: 5)),
            ]),
          );
        }),
      ],
    );
  }
}

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