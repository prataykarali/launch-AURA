part of 'students_tab.dart';

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
