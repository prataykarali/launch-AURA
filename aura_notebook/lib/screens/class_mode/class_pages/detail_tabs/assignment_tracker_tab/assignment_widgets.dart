part of '../assignment_tracker_tab.dart';

// ── Assignment card ───────────────────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final _Assignment  assignment;
  final Color        accent, color;
  final VoidCallback onSubmit;
  const _AssignmentCard({required this.assignment, required this.accent,
    required this.color, required this.onSubmit});

  String get _countdownLabel {
    if (assignment.submitted) return 'Submitted ✓';
    final days = assignment.daysLeft;
    if (days < 0)  return 'Overdue by ${-days}d';
    if (days == 0) return 'Due today!';
    return '$days days left';
  }

  Color get _countdownColor {
    if (assignment.submitted)  return Colors.greenAccent;
    if (assignment.isOverdue)  return Colors.redAccent;
    if (assignment.daysLeft <= 2) return Colors.orange;
    return accent;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF161625),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: assignment.isOverdue && !assignment.submitted
          ? Colors.redAccent.withOpacity(0.3)
          : Colors.white.withOpacity(0.06)),
    ),
    child: Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _countdownColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(assignment.submitted
                ? Icons.check_circle_rounded : Icons.assignment_outlined,
                color: _countdownColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(assignment.title,
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            if (assignment.description.isNotEmpty)
              Text(assignment.description, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.45),
                      fontSize: 12, height: 1.4)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _countdownColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _countdownColor.withOpacity(0.3)),
              ),
              child: Text(_countdownLabel,
                  style: TextStyle(color: _countdownColor, fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text('${assignment.marks} marks',
                style: TextStyle(color: Colors.white.withOpacity(0.3),
                    fontSize: 10)),
          ]),
        ]),
      ),
      // Footer
      Divider(height: 1, color: Colors.white.withOpacity(0.05)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 12,
              color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 5),
          Text(
              'Due: ${assignment.dueDate.day}/${assignment.dueDate.month}/${assignment.dueDate.year}',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          const Spacer(),
          if (!assignment.submitted)
            GestureDetector(
              onTap: onSubmit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, accent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Mark Submitted',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            )
          else
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 14),
              const SizedBox(width: 4),
              Text('+30 XP',
                  style: TextStyle(color: Colors.greenAccent.withOpacity(0.8),
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
        ]),
      ),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String l; final bool sel; final Color c; final VoidCallback t;
  const _Chip(this.l, this.sel, this.c, this.t);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? c.withOpacity(0.15) : const Color(0xFF1E1E32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sel ? c.withOpacity(0.4)
            : Colors.white.withOpacity(0.08)),
      ),
      child: Text(l, style: TextStyle(
          color: sel ? c : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String filter; final Color accent;
  const _EmptyState({required this.filter, required this.accent});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_outlined, size: 52, color: accent.withOpacity(0.3)),
      const SizedBox(height: 14),
      Text(filter == 'All' ? 'No assignments yet' : 'No $filter assignments',
          style: const TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap "+ Add" to post the first assignment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
    ]),
  );
}

class _SF extends StatelessWidget {
  final TextEditingController ctrl; final String label, hint;
  final int lines;
  const _SF({required this.ctrl, required this.label,
    required this.hint, this.lines = 1});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, maxLines: lines, minLines: 1,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}
