import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_pages/class_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClassCard — tap to open, long-press for options, delete support
// ─────────────────────────────────────────────────────────────────────────────
class ClassCard extends StatefulWidget {
  final ClassData    data;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const ClassCard({super.key, required this.data,
    this.onTap, this.onDelete});
  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _press;
  late final Animation<double>   _scale;

  // Generate a deterministic 6-char class code from the class name
  String get _classCode {
    final seed = widget.data.name.codeUnits.fold(0, (a, b) => a + b);
    final rng = Random(seed);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  void _showOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _CardOptionsSheet(
        data: widget.data,
        classCode: _classCode,
        onOpen:   () { Navigator.pop(context); widget.onTap?.call(); },
        onShare:  () { Navigator.pop(context); _shareCode(); },
        onDelete: widget.onDelete == null
            ? null
            : () { Navigator.pop(context); widget.onDelete?.call(); },
      ),
    );
  }

  void _shareCode() {
    // In a real app: Share.share('Join ${widget.data.name} with code: $_classCode');
    Clipboard.setData(ClipboardData(text: _classCode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Class code "$_classCode" copied to clipboard!'),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown:   (_) => _press.forward(),
        onTapUp:     (_) { _press.reverse(); widget.onTap?.call(); },
        onTapCancel: ()  => _press.reverse(),
        onLongPress: _showOptions,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color:      d.color.withOpacity(0.30),
              blurRadius: 24, offset: const Offset(0, 10),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Header(d: d, classCode: _classCode, onOptions: _showOptions),
              _Body(d: d),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Card header ───────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final ClassData d; final String classCode;
  final VoidCallback onOptions;
  const _Header({required this.d, required this.classCode,
    required this.onOptions});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [d.color, Color.lerp(d.color, Colors.black, 0.25)!],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Subject badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(d.subject.toUpperCase(),
                style: TextStyle(color: Colors.white.withOpacity(0.9),
                    fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 12,
                color: Colors.white.withOpacity(0.55)),
            const SizedBox(width: 4),
            Text(d.section, style: TextStyle(
                color: Colors.white.withOpacity(0.65), fontSize: 12)),
          ]),
        ]),
      ),
      const SizedBox(width: 12),
      Column(children: [
        // Icon badge
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.5),
          ),
          child: Icon(d.icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        // Options button (⋮)
        GestureDetector(
          onTap: onOptions,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.more_vert_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      ]),
    ]),
  );
}

// ── Card body ─────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final ClassData d; const _Body({required this.d});

  String get _initial =>
      d.teacher.trim().split(' ').last.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF161625),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Stats strip
      Container(
        color: const Color(0xFF0F0F1E),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [
          _Stat(Icons.people_outline_rounded,
              '${d.students} students', d.accent),
          const SizedBox(width: 16),
          _Stat(Icons.assignment_outlined, 'Assignments', d.accent),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: d.accent.withOpacity(0.3)),
            ),
            child: Text('Active', style: TextStyle(color: d.accent,
                fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      // Teacher row
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [d.accent, d.color],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Center(child: Text(_initial,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.teacher, style: const TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Class Teacher', style: TextStyle(
                    color: Colors.white.withOpacity(0.38), fontSize: 11)),
              ])),
          // Open button
          GestureDetector(
            onTap: () {}, // handled by card tap
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: d.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: d.color.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Open', style: TextStyle(color: d.accent,
                    fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: d.accent),
              ]),
            ),
          ),
        ]),
      ),
      // Divider + quick actions
      Divider(height: 1, color: Colors.white.withOpacity(0.06)),
      IntrinsicHeight(
        child: Row(children: [
          _QA(Icons.menu_book_outlined,       'Lessons',  d.accent),
          VerticalDivider(width: 1, color: Colors.white.withOpacity(0.06)),
          _QA(Icons.people_outline_rounded,   'Students', d.accent),
          VerticalDivider(width: 1, color: Colors.white.withOpacity(0.06)),
          _QA(Icons.assignment_outlined,      'Tasks',    d.accent),
          VerticalDivider(width: 1, color: Colors.white.withOpacity(0.06)),
          _QA(Icons.campaign_outlined,        'Stream',   d.accent),
        ]),
      ),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final IconData i; final String l; final Color c;
  const _Stat(this.i, this.l, this.c);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 13, color: c.withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(l, style: TextStyle(color: Colors.white.withOpacity(0.45),
            fontSize: 11)),
      ]);
}

class _QA extends StatelessWidget {
  final IconData i; final String l; final Color c;
  const _QA(this.i, this.l, this.c);
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(onTap: () {}, child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 17, color: c),
        const SizedBox(height: 4),
        Text(l, style: TextStyle(color: Colors.white.withOpacity(0.4),
            fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ]),
    )),
  );
}

// ── Card options bottom sheet ──────────────────────────────────────────────────
class _CardOptionsSheet extends StatelessWidget {
  final ClassData    data;
  final String       classCode;
  final VoidCallback onOpen, onShare;
  final VoidCallback? onDelete;
  const _CardOptionsSheet({required this.data, required this.classCode,
    required this.onOpen, required this.onShare, this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20),
    decoration: BoxDecoration(
      color: const Color(0xFF12121F),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(
        top:   BorderSide(color: data.accent.withOpacity(0.3)),
        left:  BorderSide(color: data.accent.withOpacity(0.1)),
        right: BorderSide(color: data.accent.withOpacity(0.1)),
      ),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(
          width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 16),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2)))),

      // Class header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: const TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w800)),
                Text(data.section, style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ])),
        ]),
      ),

      // Class code banner
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: data.color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(Icons.key_rounded, color: data.accent, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CLASS CODE', style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              const SizedBox(height: 3),
              Text(classCode, style: TextStyle(
                  color: data.accent, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: 4)),
              Text('Share this code with students to join',
                  style: TextStyle(color: Colors.white.withOpacity(0.3),
                      fontSize: 10)),
            ])),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: classCode));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Code "$classCode" copied!'),
                  backgroundColor: const Color(0xFF1A1A2E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.copy_rounded, size: 16, color: data.accent),
              ),
            ),
          ]),
        ),
      ),

      Divider(color: Colors.white.withOpacity(0.06)),

      // Action buttons
      _SheetAction(Icons.open_in_new_rounded, 'Open Class',
          data.accent, onOpen),
      _SheetAction(Icons.share_rounded, 'Share Class Code',
          const Color(0xFF26A69A), onShare),
      if (onDelete != null)
        _SheetAction(Icons.delete_outline_rounded, 'Delete Class',
            Colors.redAccent, onDelete!),
    ]),
  );
}

class _SheetAction extends StatelessWidget {
  final IconData i; final String l; final Color c; final VoidCallback onTap;
  const _SheetAction(this.i, this.l, this.c, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(i, color: c, size: 18),
    ),
    title: Text(l, style: TextStyle(color: c == Colors.redAccent
        ? Colors.redAccent : Colors.white,
        fontSize: 14, fontWeight: FontWeight.w600)),
    onTap: onTap,
  );
}