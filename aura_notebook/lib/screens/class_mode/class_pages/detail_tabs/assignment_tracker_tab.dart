import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AssignmentTrackerTab — full assignment lifecycle
// • Teacher posts assignment with title, description, due date, marks
// • Countdown badges (days remaining / overdue)
// • Students mark submitted → earns XP
// • Filter: All / Active / Submitted / Overdue
// ─────────────────────────────────────────────────────────────────────────────
class AssignmentTrackerTab extends StatefulWidget {
  final ClassData data;
  final void Function(int xp) onXpEarned;

  const AssignmentTrackerTab({super.key, required this.data,
    required this.onXpEarned});

  @override
  State<AssignmentTrackerTab> createState() => _AssignmentTrackerTabState();
}

class _AssignmentTrackerTabState extends State<AssignmentTrackerTab> {
  final List<_Assignment> _assignments = [];
  String _filter = 'All'; // All | Active | Submitted | Overdue

  List<_Assignment> get _filtered => switch (_filter) {
    'Active'    => _assignments.where((a) => !a.submitted && !a.isOverdue).toList(),
    'Submitted' => _assignments.where((a) => a.submitted).toList(),
    'Overdue'   => _assignments.where((a) => a.isOverdue && !a.submitted).toList(),
    _           => _assignments,
  };

  void _openAddSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    final marksCtrl = TextEditingController();
    DateTime pickedDue = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final b = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + b),
            decoration: const BoxDecoration(
              color: Color(0xFF12121F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)))),
                  const Text('New Assignment',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _SF(ctrl: titleCtrl, label: 'Title *',      hint: 'e.g. Chapter 5 Summary'),
                  const SizedBox(height: 10),
                  _SF(ctrl: descCtrl,  label: 'Description',  hint: 'What students need to do…', lines: 2),
                  const SizedBox(height: 10),
                  _SF(ctrl: marksCtrl, label: 'Marks',        hint: 'e.g. 10'),
                  const SizedBox(height: 14),
                  // Due date picker
                  GestureDetector(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: pickedDue,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                    primary: widget.data.accent)),
                            child: child!),
                      );
                      if (p != null) setSt(() => pickedDue = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.data.accent.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16, color: widget.data.accent),
                        const SizedBox(width: 10),
                        Text('Due: ${pickedDue.day}/${pickedDue.month}/${pickedDue.year}',
                            style: TextStyle(color: widget.data.accent, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('Tap to change',
                            style: TextStyle(color: Colors.white.withOpacity(0.25),
                                fontSize: 11)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isNotEmpty) {
                          setState(() => _assignments.insert(0, _Assignment(
                            title:       titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            marks:       int.tryParse(marksCtrl.text) ?? 10,
                            dueDate:     pickedDue,
                          )));
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: widget.data.color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text('Post Assignment',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ]),
          );
        },
      ),
    );
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in ['All', 'Active', 'Submitted', 'Overdue'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(f, _filter == f, d.accent,
                            () => setState(() => _filter = f)),
                  ),
              ]),
            ),
          ),
          GestureDetector(
            onTap: _openAddSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: d.color, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      // ── List ─────────────────────────────────────────────────────────
      Expanded(
        child: _filtered.isEmpty
            ? _EmptyState(filter: _filter, accent: d.accent)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _AssignmentCard(
            assignment: _filtered[i],
            accent: d.accent, color: d.color,
            onSubmit: () {
              HapticFeedback.mediumImpact();
              setState(() => _filtered[i].submitted = true);
              widget.onXpEarned(30); // 30 XP per submission
            },
          ),
        ),
      ),
    ]);
  }
}

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

class _Assignment {
  final String   title, description;
  final int      marks;
  final DateTime dueDate;
  bool           submitted = false;

  _Assignment({required this.title, required this.description,
    required this.marks, required this.dueDate});

  int  get daysLeft  => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => daysLeft < 0;
}