import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../class_data.dart';
import '../../student_model.dart';
import '../../detail_widgets/dark_card.dart';
import '../../detail_widgets/empty_state.dart';

part 'roster_view.dart';
part 'catch_up_view.dart';
part 'cr_panel_view.dart';
part 'add_sheet_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StudentsTab — uses shared StudentModel list.
// When a student is added/removed, onStudentsChanged is called so
// ClassDetailPage can update the same list used by AttendanceTab.
// ─────────────────────────────────────────────────────────────────────────────
class StudentsTab extends StatefulWidget {
  final ClassData                        data;
  final List<StudentModel>               students;
  final void Function(List<StudentModel>) onStudentsChanged;

  const StudentsTab({
    super.key,
    required this.data,
    required this.students,
    required this.onStudentsChanged,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab>
    with SingleTickerProviderStateMixin {

  late final TabController _inner;

  // Local mutable copy — synced back via onStudentsChanged
  late List<StudentModel> _students;

  String get _classCode {
    final seed = widget.data.name.codeUnits.fold(0, (a, b) => a + b);
    final rng  = Random(seed);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _inner    = TabController(length: 3, vsync: this);
    _students = List.from(widget.students);
  }

  @override
  void didUpdateWidget(StudentsTab old) {
    super.didUpdateWidget(old);
    // Sync if parent pushed changes
    if (widget.students.length != _students.length) {
      setState(() => _students = List.from(widget.students));
    }
  }

  @override
  void dispose() { _inner.dispose(); super.dispose(); }

  void _addStudent(StudentModel s) {
    setState(() => _students.add(s));
    widget.onStudentsChanged(List.from(_students));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(children: [
      // Inner tab bar
      Container(
        color: const Color(0xFF0D0D18),
        child: TabBar(
          controller: _inner,
          indicatorColor:        d.accent,
          indicatorWeight:       2,
          labelColor:            d.accent,
          unselectedLabelColor:  Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Roster'),
            Tab(text: 'Catch-Up'),
            Tab(text: 'CR Panel'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _inner, children: [
          _RosterView(
            students: _students, data: d, classCode: _classCode,
            onAdd: () => _showAddSheet(context, d, isCR: false),
          ),
          _CatchUpView(students: _students, accent: d.accent),
          _CRPanelView(
            accent: d.accent, data: d, classCode: _classCode,
            onAddCR: () => _showAddSheet(context, d, isCR: true),
          ),
        ]),
      ),
    ]);
  }

  void _showAddSheet(BuildContext ctx, ClassData d, {required bool isCR}) {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final b = MediaQuery.of(ctx).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + b),
          decoration: const BoxDecoration(
            color: Color(0xFF12121F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [

                Center(child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),

                Text(isCR ? 'Add Class Representative' : 'Add Student',
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),

                // Class code display
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: d.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: d.color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Icon(Icons.key_rounded, color: d.accent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SHARE CLASS CODE', style: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      Text(_classCode, style: TextStyle(color: d.accent,
                          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    ])),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _classCode));
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('Code "$_classCode" copied!'),
                          backgroundColor: const Color(0xFF1A1A2E),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: d.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.copy_rounded, size: 14, color: d.accent),
                      ),
                    ),
                  ]),
                ),

                _SF(ctrl: nameCtrl,
                    label: isCR ? 'CR Name *' : 'Student Name *',
                    hint:  'e.g. Aditya Kumar'),
                const SizedBox(height: 10),
                _SF(ctrl: rollCtrl, label: 'Roll Number', hint: 'e.g. 01'),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        _addStudent(StudentModel(
                          name: nameCtrl.text.trim(),
                          roll: rollCtrl.text.isNotEmpty
                              ? 'Roll ${rollCtrl.text}'
                              : 'Roll ${_students.length + 1}',
                          isCR: isCR,
                        ));
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: d.color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(isCR ? 'Add CR' : 'Add Student',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        );
      },
    );
  }
}
