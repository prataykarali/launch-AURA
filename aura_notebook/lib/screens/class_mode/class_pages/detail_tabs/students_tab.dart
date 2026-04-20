import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';
import '../student_model.dart';
import '../detail_widgets/dark_card.dart';
import '../detail_widgets/empty_state.dart';

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

// ── Catch-Up ──────────────────────────────────────────────────────────────────
class _CatchUpView extends StatelessWidget {
  final List<StudentModel> students; final Color accent;
  const _CatchUpView({required this.students, required this.accent});
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.check_circle_outline_rounded,
        size: 48, color: Colors.greenAccent.withOpacity(0.5)),
    const SizedBox(height: 12),
    Text('All caught up!', style: TextStyle(
        color: Colors.white.withOpacity(0.4), fontSize: 15,
        fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('No students need catch-up materials.', style: TextStyle(
        color: Colors.white.withOpacity(0.25), fontSize: 12)),
  ]));
}

// ── CR Panel ──────────────────────────────────────────────────────────────────
class _CRPanelView extends StatefulWidget {
  final Color accent; final ClassData data;
  final String classCode; final VoidCallback onAddCR;
  const _CRPanelView({required this.accent, required this.data,
    required this.classCode, required this.onAddCR});
  @override
  State<_CRPanelView> createState() => _CRPanelViewState();
}

class _CRPanelViewState extends State<_CRPanelView> {
  final _items = [
    _CRItem('Resource uploaded: Week 4 Slides', pending: true),
    _CRItem('Lesson 8 notes marked complete',   pending: false),
    _CRItem('Student query: Exam date change?', pending: true),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Verification Panel', Icons.verified_outlined,
                const Color(0xFF7C4DFF)),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((e) => _CRRow(
              item: e.value, accent: widget.accent,
              onApprove: () => setState(() =>
              _items[e.key] = _CRItem(e.value.text, pending: false)),
            )),
          ])),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: widget.onAddCR,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161625),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.person_add_rounded, color: widget.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Class Representative',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text('Moderate discussions & verify updates',
                  style: TextStyle(color: Colors.white.withOpacity(0.35),
                      fontSize: 11)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 12,
                color: Colors.white.withOpacity(0.25)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Discussion Threads', Icons.forum_outlined, widget.accent),
            const SizedBox(height: 10),
            _ThreadRow('When is the next test?',        '3 replies'),
            _ThreadRow('Chapter 5 reference material?', '1 reply'),
            _ThreadRow('Assignment submission format',  '5 replies'),
          ])),
    ],
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _CRItem { final String text; final bool pending;
const _CRItem(this.text, {required this.pending}); }

class _CRRow extends StatelessWidget {
  final _CRItem item; final Color accent; final VoidCallback onApprove;
  const _CRRow({required this.item, required this.accent,
    required this.onApprove});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(item.pending ? Icons.pending_outlined : Icons.check_circle_rounded,
          size: 16, color: item.pending ? Colors.orange : Colors.greenAccent),
      const SizedBox(width: 10),
      Expanded(child: Text(item.text, style: TextStyle(
          color: Colors.white.withOpacity(0.6), fontSize: 12))),
      if (item.pending) GestureDetector(
        onTap: onApprove,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Text('Approve', style: TextStyle(color: accent,
              fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );
}

class _ThreadRow extends StatelessWidget {
  final String q, r; const _ThreadRow(this.q, this.r);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      const Icon(Icons.chat_bubble_outline_rounded,
          size: 14, color: Colors.white38),
      const SizedBox(width: 10),
      Expanded(child: Text(q, style: TextStyle(
          color: Colors.white.withOpacity(0.55), fontSize: 12))),
      Text(r, style: TextStyle(
          color: Colors.white.withOpacity(0.28), fontSize: 10)),
    ]),
  );
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

class _SF extends StatelessWidget {
  final TextEditingController ctrl; final String label, hint;
  const _SF({required this.ctrl, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12),
      hintStyle:  TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C6BC0), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
  );
}