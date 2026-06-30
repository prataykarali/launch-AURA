import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../class_data.dart';
import '../../detail_widgets/dark_card.dart';
import '../../detail_widgets/smart_briefing_card.dart';
import 'add_topic_sheet.dart';
import 'leaderboard_sheet.dart';
import 'level_card.dart';
import 'metric_stat.dart';
import 'stat_box.dart';
import 'topic_model.dart';
import 'topic_tile.dart';

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
  late List<Topic> _topics;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);

    // Pre-populate topics from subject theme defaults
    final theme = themeFor(widget.data.subject);
    _topics = theme.defaultTopics.map((t) => Topic(title: t)).toList();

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
  void _openLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaderboardSheet(
        data: widget.data,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  // ── Add topic sheet ───────────────────────────────────────────────────────
  void _showAddTopic() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final b = MediaQuery.of(ctx).viewInsets.bottom;
        return AddTopicSheet(
          data: widget.data,
          bottomInset: b,
          onAdd: (val) => setState(() => _topics.add(Topic(title: val))),
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
    LevelCard(
    xp:       _totalXp,
    level:    _level,
    xpIn:     _xpIn,
    xpNeeded: _xpNeeded,
    accent:   d.accent,
    anim:     _anim,
    ),
    const SizedBox(height: 14),

    // ── Leaderboard button ───────────────────────────────────────────
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
    Row(children: [
    MetricStat('Done',  '$_done',          d.accent),
    MetricStat('Left',  '${_total - _done}', Colors.orange),
    MetricStat('Total', '$_total',          Colors.white38),
    ]),
    ])),
    const SizedBox(height: 14),

    // ── Quick stat boxes ─────────────────────────────────────────────
    Row(children: [
    Expanded(child: StatBox('${d.students}', 'Students',
    Icons.people_rounded,          d.accent)),
    const SizedBox(width: 10),
    Expanded(child: StatBox('$_total', 'Topics',
    Icons.menu_book_rounded,       const Color(0xFFFFB74D))),
    const SizedBox(width: 10),
    Expanded(child: StatBox('$_done',  'Done',
    Icons.check_circle_rounded,    const Color(0xFF81C784))),
    const SizedBox(width: 10),
    Expanded(child: StatBox('${_total - _done}', 'Left',
    Icons.hourglass_bottom_rounded, Colors.orange)),
    ]),
    const SizedBox(height: 18),

    // ── Syllabus topics header ────────────────────────────────────────
    Row(children: [
    Expanded(child: CardTitle('Syllabus Topics',
    Icons.list_alt_rounded, d.accent)),
    // ── Add Topic button ────────────────────────────────────────────
    GestureDetector(
    onTap: _showAddTopic,
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
    ..._topics.asMap().entries.map((e) => TopicTile(
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
