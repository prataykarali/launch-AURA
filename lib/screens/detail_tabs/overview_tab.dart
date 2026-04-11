import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';
import '../detail_widgets/dark_card.dart';
import '../detail_widgets/smart_briefing_card.dart';
import 'leaderboard_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OverviewTab — XP system, syllabus tracker, smart briefing, leaderboard
// ─────────────────────────────────────────────────────────────────────────────
class OverviewTab extends StatefulWidget {
  final ClassData      data;
  final int            externalXp;
  final void Function(int) onXpEarned;

  const OverviewTab({
    super.key,
    required this.data,
    this.externalXp = 0,
    required this.onXpEarned,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ac;
  late final Animation<double>   _anim;

  int               _xp     = 0;
  late List<_Topic> _topics;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);

    // Pre-populate topics from subject theme defaults
    final theme = themeFor(widget.data.subject);
    _topics = theme.defaultTopics.map((t) => _Topic(title: t)).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) => _ac.forward());
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  // ── Topic toggle ──────────────────────────────────────────────────────────
  void _toggle(int i) {
    HapticFeedback.lightImpact();
    final wasDone = _topics[i].done;
    setState(() {
      _topics[i] = _topics[i].toggle();
      _xp = (_xp + (wasDone ? -25 : 25)).clamp(0, 99999);
    });
    _ac.reset();
    _ac.forward();
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  int    get _done     => _topics.where((t) => t.done).length;
  int    get _total    => _topics.length;
  double get _progress => _total == 0 ? 0 : _done / _total;
  int    get _totalXp  => _xp + widget.externalXp;
  int    get _level    => XpSystem.levelFromXp(_totalXp);
  int    get _xpIn     => XpSystem.xpInCurrentLevel(_totalXp);
  int    get _xpNeeded => XpSystem.xpNeededForCurrentLevel(_totalXp);

  // ── Open leaderboard ──────────────────────────────────────────────────────
  // FIX: show as a bottom sheet, NOT nested in the ListView
  void _openLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top:   BorderSide(color: Color(0x335C6BC0)),
            left:  BorderSide(color: Color(0x225C6BC0)),
            right: BorderSide(color: Color(0x225C6BC0)),
          ),
        ),
        child: Column(children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Center(child: Container(
                width: 38, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2)),
              )),
              Row(children: [
                Icon(Icons.leaderboard_rounded,
                    color: widget.data.accent, size: 20),
                const SizedBox(width: 10),
                Text('Class Leaderboard',
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.35), size: 20)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          // Leaderboard content fills the rest
          Expanded(child: LeaderboardTab(data: widget.data)),
        ]),
      ),
    );
  }

  // ── Add topic sheet ───────────────────────────────────────────────────────
  void _showAddTopic() {
    final ctrl = TextEditingController();
    final d    = widget.data;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final b = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setSt) => Container(
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
                  const Text('Add Syllabus Topic',
                      style: TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl, autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() =>
                            _topics.add(_Topic(title: val.trim())));
                      }
                      Navigator.pop(ctx);
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. Quadratic Equations',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2), fontSize: 13),
                      filled: true, fillColor: const Color(0xFF1E1E32),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: d.accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final val = ctrl.text.trim();
                        if (val.isNotEmpty) {
                          // ← setState on the OverviewTab state, not the sheet
                          setState(() => _topics.add(_Topic(title: val)));
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: d.color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: const Text('Add Topic',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

      // ── Smart Briefing ───────────────────────────────────────────────
      SmartBriefingCard(
      data:         d,
      topicsDone:   _done,
      topicsTotal:  _total,
      xp:           _totalXp,
      studentCount: d.students,
    ),
    const SizedBox(height: 14),

    // ── XP / Level card ──────────────────────────────────────────────
    _LevelCard(
    xp:       _totalXp,
    level:    _level,
    xpIn:     _xpIn,
    xpNeeded: _xpNeeded,
    accent:   d.accent,
    anim:     _anim,
    ),
    const SizedBox(height: 14),

    // ── Leaderboard button ───────────────────────────────────────────
    // FIX: button opens leaderboard as bottom sheet, not nested widget
    GestureDetector(
    onTap: _openLeaderboard,
    child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
    color: const Color(0xFF161625),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: d.accent.withOpacity(0.2)),
    ),
    child: Row(children: [
    Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
    color: d.accent.withOpacity(0.12),
    borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.leaderboard_rounded,
    color: d.accent, size: 18),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Class Leaderboard',
    style: TextStyle(color: Colors.white, fontSize: 13,
    fontWeight: FontWeight.w700)),
    Text("See who's earning the most XP",
    style: TextStyle(color: Colors.white.withOpacity(0.35),
    fontSize: 11)),
    ])),
    Icon(Icons.arrow_forward_ios_rounded,
    size: 13, color: Colors.white.withOpacity(0.25)),
    ]),
    ),
    ),
    const SizedBox(height: 14),

    // ── Syllabus progress ────────────────────────────────────────────
    DarkCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    CardTitle('Syllabus Progress',
    Icons.track_changes_rounded, d.accent),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text('${(_progress * 100).toInt()}% completed',
    style: TextStyle(color: Colors.white.withOpacity(0.5),
    fontSize: 12)),
    Text('$_done / $_total topics',
    style: TextStyle(color: d.accent, fontSize: 12,
    fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 7),
    AnimatedBuilder(animation: _anim, builder: (_, __) =>
    ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
    value: _progress * _anim.value,
    backgroundColor: Colors.white.withOpacity(0.07),
    valueColor: AlwaysStoppedAnimation(d.accent),
    minHeight: 8,
    ),
    ),
    ),
    const SizedBox(height: 12),
    // FIX: _MS now takes 3 params only
    Row(children: [
    _MS('Done',  '$_done',          d.accent),
    _MS('Left',  '${_total - _done}', Colors.orange),
    _MS('Total', '$_total',          Colors.white38),
    ]),
    ])),
    const SizedBox(height: 14),

    // ── Quick stat boxes ─────────────────────────────────────────────
    Row(children: [
    Expanded(child: _SBox('${d.students}', 'Students',
    Icons.people_rounded,          d.accent)),
    const SizedBox(width: 10),
    Expanded(child: _SBox('$_total', 'Topics',
    Icons.menu_book_rounded,       const Color(0xFFFFB74D))),
    const SizedBox(width: 10),
    Expanded(child: _SBox('$_done',  'Done',
    Icons.check_circle_rounded,    const Color(0xFF81C784))),
    const SizedBox(width: 10),
    Expanded(child: _SBox('${_total - _done}', 'Left',
    Icons.hourglass_bottom_rounded, Colors.orange)),
    ]),
    const SizedBox(height: 18),

    // ── Syllabus topics header ────────────────────────────────────────
    Row(children: [
    Expanded(child: CardTitle('Syllabus Topics',
    Icons.list_alt_rounded, d.accent)),
    // ── Add Topic button ────────────────────────────────────────────
    GestureDetector(
    onTap: _showAddTopic,   // ← calls the method above
    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
    color: d.color.withOpacity(0.18),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: d.color.withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.add_rounded, size: 13, color: d.accent),
    const SizedBox(width: 4),
    Text('Add Topic',
    style: TextStyle(color: d.accent, fontSize: 11,
    fontWeight: FontWeight.w700)),
    ]),
    ),
    ),
    ]),
    const SizedBox(height: 10),

    // ── Topic tiles ──────────────────────────────────────────────────
    ..._topics.asMap().entries.map((e) => _TopicTile(
    topic:    e.value,
    index:    e.key + 1,
    accent:   d.accent,
    color:    d.color,
    onToggle: () => _toggle(e.key),
    onDelete: () => setState(() {
    if (e.value.done) _xp = (_xp - 25).clamp(0, 99999);
    _topics.removeAt(e.key);
    }),
    )),

    if (_topics.isEmpty)
    Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
    child: Text('No topics yet. Tap "Add Topic" to begin.',
    style: TextStyle(color: Colors.white.withOpacity(0.28),
    fontSize: 13)),
    ),
    ),
    ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── Topic tile ────────────────────────────────────────────────────────────────
class _TopicTile extends StatelessWidget {
  final _Topic topic; final int index;
  final Color accent, color;
  final VoidCallback onToggle, onDelete;
  const _TopicTile({required this.topic, required this.index,
    required this.accent, required this.color,
    required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        topic.done ? color.withOpacity(0.12) : const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: topic.done
            ? accent.withOpacity(0.35) : Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  topic.done ? accent : Colors.transparent,
            border: Border.all(
                color: topic.done ? accent : Colors.white30, width: 2),
          ),
          child: topic.done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : Center(child: Text('$index', style: TextStyle(
              color: Colors.white24, fontSize: 10,
              fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(topic.title,
            style: TextStyle(
              color: topic.done
                  ? Colors.white.withOpacity(0.45) : Colors.white,
              fontSize: 13, fontWeight: FontWeight.w500,
              decoration: topic.done ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white30,
            ))),
        if (topic.done) ...[
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('+25 XP', style: TextStyle(color: accent,
                  fontSize: 9, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
        ],
        GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 15,
                color: Colors.white.withOpacity(0.18))),
      ]),
    ),
  );
}

// ── Level card ────────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final int xp, level, xpIn, xpNeeded;
  final Color accent; final Animation<double> anim;
  const _LevelCard({required this.xp, required this.level,
    required this.xpIn, required this.xpNeeded,
    required this.accent, required this.anim});

  @override
  Widget build(BuildContext context) {
    final pct   = xpNeeded == 0 ? 0.0 : xpIn / xpNeeded;
    final title = XpSystem.levelTitle(level);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: [const Color(0xFF1A1A2E), accent.withOpacity(0.1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              accent.withOpacity(0.9), accent.withOpacity(0.25)]),
            boxShadow: [BoxShadow(
                color: accent.withOpacity(0.35), blurRadius: 16)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lv', style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9, fontWeight: FontWeight.w600)),
                Text('$level', style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
              ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Class Level $level',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(title, style: TextStyle(color: accent.withOpacity(0.7),
                              fontSize: 10, fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                        ]),
                    Text('$xpIn / $xpNeeded XP',
                        style: TextStyle(color: accent, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
              const SizedBox(height: 8),
              AnimatedBuilder(animation: anim, builder: (_, __) =>
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                          value: pct * anim.value,
                          backgroundColor: Colors.white.withOpacity(0.07),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 7))),
              const SizedBox(height: 5),
              xp == 0
                  ? Text('Complete topics to earn XP!',
                  style: TextStyle(color: Colors.white.withOpacity(0.3),
                      fontSize: 10))
                  : Text('${xpNeeded - xpIn} XP to Lv ${level + 1} · ${XpSystem.levelTitle(level + 1)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.35),
                      fontSize: 10)),
            ])),
      ]),
    );
  }
}

// ── _MS — 3 params only (was 4, caused compile error) ────────────────────────
class _MS extends StatelessWidget {
  final String l, v; final Color c;
  const _MS(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 18,
        fontWeight: FontWeight.w800)),
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3),
        fontSize: 9)),
  ]));
}

class _SBox extends StatelessWidget {
  final String v, l; final IconData i; final Color c;
  const _SBox(this.v, this.l, this.i, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: [
      Icon(i, size: 18, color: c),
      const SizedBox(height: 6),
      Text(v, style: TextStyle(color: c, fontSize: 18,
          fontWeight: FontWeight.w800)),
      Text(l, style: TextStyle(color: Colors.white.withOpacity(0.3),
          fontSize: 9)),
    ]),
  );
}

// ── Data model ────────────────────────────────────────────────────────────────
class _Topic {
  final String title; final bool done;
  const _Topic({required this.title, this.done = false});
  _Topic toggle() => _Topic(title: title, done: !done);
}