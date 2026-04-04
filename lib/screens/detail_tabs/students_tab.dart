import 'package:flutter/material.dart';
import '../class_data.dart';
import '../detail_widgets/dark_card.dart';
import '../detail_widgets/section_label.dart';
import '../detail_widgets/empty_state.dart';

// IMAGE PLACEHOLDER:
//   • Assets/images/empty_students.png → empty state (300×250)
//     Suggest: group of cartoon students / silhouettes

class StudentsTab extends StatefulWidget {
  final ClassData data;
  const StudentsTab({super.key, required this.data});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab>
    with SingleTickerProviderStateMixin {

  late final TabController _inner;
  final List<_Student> _students = []; // ← starts empty

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 3, vsync: this);
  }
  @override
  void dispose() { _inner.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        // ── Inner tab bar ─────────────────────────────────────────────
        Container(
          color: const Color(0xFF0D0D18),
          child: TabBar(
            controller: _inner,
            indicatorColor: d.accent,
            indicatorWeight: 2,
            labelColor: d.accent,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(text: 'Roster'),
              Tab(text: 'Catch-Up'),
              Tab(text: 'CR Panel'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _inner,
            children: [
              _RosterView(students: _students, data: d,
                  onAdd: () => _showAddSheet(context, d)),
              _CatchUpView(students: _students, accent: d.accent),
              _CRPanelView(accent: d.accent),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext ctx, ClassData d) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
              const Text('Add Student',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _SF(ctrl: nameCtrl, label: 'Full Name *', hint: 'e.g. Aditya Kumar'),
              const SizedBox(height: 10),
              _SF(ctrl: rollCtrl, label: 'Roll Number', hint: 'e.g. 01'),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() => _students.add(_Student(
                        name: nameCtrl.text.trim(),
                        roll: 'Roll ${rollCtrl.text.isNotEmpty ? rollCtrl.text : _students.length + 1}',
                      )));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: d.color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('Add Student',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Roster ────────────────────────────────────────────────────────────────────
class _RosterView extends StatelessWidget {
  final List<_Student> students; final ClassData data;
  final VoidCallback onAdd;
  const _RosterView({required this.students, required this.data,
    required this.onAdd});
  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return EmptyState(
        imagePath: 'Assets/images/empty_students.png',
        title: "No Students Yet",
        subtitle: 'Add students to build your class roster.',
        accent: data.accent,
        action: _AddBtn(label: 'Add Student', color: data.color,
            accent: data.accent, onTap: onAdd),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Text('${students.length} students',
              style: TextStyle(color: Colors.white.withOpacity(0.35),
                  fontSize: 12)),
          const Spacer(),
          _AddBtn(label: 'Add', color: data.color, accent: data.accent, onTap: onAdd),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: students.length,
          itemBuilder: (_, i) => _StudentTile(
            student: students[i], accent: data.accent, index: i,
          ),
        ),
      ),
    ]);
  }
}

// ── Catch-Up ──────────────────────────────────────────────────────────────────
class _CatchUpView extends StatelessWidget {
  final List<_Student> students; final Color accent;
  const _CatchUpView({required this.students, required this.accent});
  @override
  Widget build(BuildContext context) {
    final absent = students.where((s) => s.status == 'Absent').toList();
    if (absent.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 48, color: Colors.greenAccent.withOpacity(0.5)),
        const SizedBox(height: 12),
        Text('All caught up!',
            style: TextStyle(color: Colors.white.withOpacity(0.4),
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('No students need catch-up materials.',
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12)),
      ]));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Missed Class', Icons.event_busy_rounded, Colors.orange),
        const SizedBox(height: 10),
        ...absent.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            CircleAvatar(radius: 16,
                backgroundColor: Colors.orange.withOpacity(0.15),
                child: Text(s.name[0],
                    style: const TextStyle(color: Colors.orange,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(child: Text(s.name,
                style: const TextStyle(color: Colors.white, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Share Notes',
                  style: TextStyle(color: Colors.orange, fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        )),
      ])),
    ]);
  }
}

// ── CR Panel ──────────────────────────────────────────────────────────────────
class _CRPanelView extends StatefulWidget {
  final Color accent;
  const _CRPanelView({required this.accent});
  @override
  State<_CRPanelView> createState() => _CRPanelViewState();
}

class _CRPanelViewState extends State<_CRPanelView> {
  final List<_CRItem> _items = [
    _CRItem('Resource uploaded: Week 4 Slides', pending: true),
    _CRItem('Lesson 8 notes marked complete',   pending: false),
    _CRItem('Student query: Exam date change?', pending: true),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Verification Panel', Icons.verified_outlined,
            const Color(0xFF7C4DFF)),
        const SizedBox(height: 12),
        ..._items.asMap().entries.map((e) => _CRRow(
          item: e.value,
          accent: widget.accent,
          onApprove: () => setState(() => _items[e.key] = _CRItem(
              e.value.text, pending: false)),
        )),
      ])),
      const SizedBox(height: 14),
      DarkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Discussion Threads', Icons.forum_outlined, widget.accent),
        const SizedBox(height: 10),
        _ThreadRow('When is the next test?',        '3 replies'),
        _ThreadRow('Chapter 5 reference material?', '1 reply'),
        _ThreadRow('Assignment submission format',  '5 replies'),
      ])),
    ]);
  }
}

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
      Expanded(child: Text(item.text,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12))),
      if (item.pending)
        GestureDetector(
          onTap: onApprove,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text('Approve',
                style: TextStyle(color: accent, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ),
    ]),
  );
}

class _ThreadRow extends StatelessWidget {
  final String q, replies; const _ThreadRow(this.q, this.replies);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      const Icon(Icons.chat_bubble_outline_rounded,
          size: 14, color: Colors.white38),
      const SizedBox(width: 10),
      Expanded(child: Text(q,
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12))),
      Text(replies,
          style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 10)),
    ]),
  );
}

// ── Data ──────────────────────────────────────────────────────────────────────
class _Student {
  final String name, roll, status;
  const _Student({required this.name, required this.roll,
    this.status = 'Present'});
}

class _StudentTile extends StatelessWidget {
  final _Student student; final Color accent; final int index;
  const _StudentTile({required this.student, required this.accent,
    required this.index});
  Color get _sc => switch (student.status) {
    'Absent' => Colors.redAccent, 'Late' => Colors.orange,
    _        => Colors.greenAccent,
  };
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Row(children: [
      CircleAvatar(radius: 17, backgroundColor: accent.withOpacity(0.15),
          child: Text(student.name[0],
              style: TextStyle(color: accent, fontWeight: FontWeight.w800))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.name, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600)),
            Text(student.roll, style: TextStyle(
                color: Colors.white.withOpacity(0.33), fontSize: 11)),
          ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _sc.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(student.status,
            style: TextStyle(color: _sc, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _AddBtn extends StatelessWidget {
  final String label; final Color color, accent; final VoidCallback onTap;
  const _AddBtn({required this.label, required this.color,
    required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
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