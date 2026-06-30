part of 'students_tab.dart';

// ── Roster ────────────────────────────────────────────────────────────────────
class _RosterView extends StatelessWidget {
  final List<StudentModel> students;
  final ClassData          data;
  final String             classCode;
  final VoidCallback       onAdd;

  const _RosterView({required this.students, required this.data,
    required this.classCode, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return EmptyState(
        imagePath: 'Assets/images/empty_students.png',
        title:    'No Students Yet',
        subtitle: 'Add students or share the class code for them to join.',
        accent:   data.accent,
        action: _AddBtn(l: 'Add Student',
            c: data.color, accent: data.accent, onTap: onAdd),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(child: Text('${students.length} enrolled',
              style: TextStyle(color: Colors.white.withOpacity(0.35),
                  fontSize: 12))),
          _AddBtn(l: 'Add', c: data.color,
              accent: data.accent, onTap: onAdd),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: students.length,
          itemBuilder: (_, i) => _StudentTile(
              student: students[i], accent: data.accent),
        ),
      ),
    ]);
  }
}

class _StudentTile extends StatelessWidget {
  final StudentModel student; final Color accent;
  const _StudentTile({required this.student, required this.accent});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Row(children: [
      Stack(children: [
        CircleAvatar(radius: 18, backgroundColor: accent.withOpacity(0.15),
            child: Text(student.name[0], style: TextStyle(
                color: accent, fontWeight: FontWeight.w800))),
        if (student.isCR)
          Positioned(right: 0, bottom: 0, child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF), shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D0D18), width: 1.5)),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 8))),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(student.name, style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              if (student.isCR) ...[
                const SizedBox(width: 6),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('CR', style: TextStyle(
                        color: Color(0xFF7C4DFF), fontSize: 9,
                        fontWeight: FontWeight.w800))),
              ],
            ]),
            Text(student.roll, style: TextStyle(
                color: Colors.white.withOpacity(0.33), fontSize: 11)),
          ])),
    ]),
  );
}

class _AddBtn extends StatelessWidget {
  final String l; // Label
  final Color c;  // Color
  final Color accent; // <-- ADD THIS FIELD HERE
  final VoidCallback onTap;

  // Now the constructor matches the fields above
  const _AddBtn({
    required this.l,
    required this.c,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Note: If you have a helper method returning another _AddBtn inside here,
    // make sure it passes 'accent' and 'onTap' instead of 'a' and 't'.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Text(l, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// workaround for named param pattern
extension _AddBtnExt on _AddBtn {
  // ignore
}
// simpler alias used above
class _AddButtonAlias extends StatelessWidget {
  final String label; final Color color, accent; final VoidCallback onTap;
  const _AddButtonAlias({required this.label, required this.color,
    required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_rounded, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: accent, fontSize: 12,
            fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}
