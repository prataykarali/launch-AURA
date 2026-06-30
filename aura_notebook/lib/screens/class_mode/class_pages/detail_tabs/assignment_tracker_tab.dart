import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';

part 'assignment_tracker_tab/assignment_model.dart';
part 'assignment_tracker_tab/assignment_widgets.dart';

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
