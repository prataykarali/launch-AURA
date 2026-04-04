import 'package:flutter/material.dart';
import '../class_data.dart';
import '../detail_widgets/dark_card.dart';
import '../detail_widgets/section_label.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// OverviewTab — syllabus progress, XP level system, stats, upcoming, smart feed.
///
/// IMAGE PLACEHOLDERS:
///   • Assets/images/level_badge.png  → circular XP badge (64×64 transparent PNG)
///   • Assets/images/smart_feed_bg.png → subtle bg for Smart Feed card (optional)
// ─────────────────────────────────────────────────────────────────────────────
class OverviewTab extends StatefulWidget {
  final ClassData data;
  const OverviewTab({super.key, required this.data});
  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab>
    with SingleTickerProviderStateMixin {

  // XP system state (in real app: persist via shared_prefs or DB)
  int    _xp       = 340;
  int    _level    = 4;
  double _xpToNext = 500;

  late final AnimationController _progressAnim;
  late final Animation<double>   _barAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _barAnim = CurvedAnimation(parent: _progressAnim, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _progressAnim.forward());
  }

  @override
  void dispose() { _progressAnim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [

        // ── XP / Level card ──────────────────────────────────────────────
        _LevelCard(
          level: _level, xp: _xp, xpToNext: _xpToNext,
          accent: d.accent, barAnim: _barAnim,
        ),
        const SizedBox(height: 14),

        // ── Syllabus progress ────────────────────────────────────────────
        DarkCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Syllabus Progress', Icons.track_changes_rounded, d.accent),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('67% completed',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
              Text('8 / 12 topics',
                  style: TextStyle(color: d.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            AnimatedBuilder(animation: _barAnim, builder: (_, __) =>
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.67 * _barAnim.value,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: AlwaysStoppedAnimation(d.accent),
                    minHeight: 8,
                  ),
                ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _MiniStat('Done',      '8', d.accent),
              _MiniStat('Left',      '4', Colors.orange),
              _MiniStat('Overdue',   '2', Colors.redAccent),
              _MiniStat('This Week', '1', const Color(0xFF7C4DFF)),
            ]),
          ],
        )),
        const SizedBox(height: 14),

        // ── Quick stat boxes ─────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatBox('${d.students}', 'Students',
              Icons.people_rounded, d.accent)),
          const SizedBox(width: 10),
          Expanded(child: _StatBox('12', 'Lessons',
              Icons.menu_book_rounded, const Color(0xFFFFB74D))),
          const SizedBox(width: 10),
          Expanded(child: _StatBox('24', 'Files',
              Icons.folder_rounded, const Color(0xFF81C784))),
          const SizedBox(width: 10),
          Expanded(child: _StatBox('3', 'Alerts',
              Icons.notifications_rounded, Colors.redAccent)),
        ]),
        const SizedBox(height: 14),

        // ── Upcoming ─────────────────────────────────────────────────────
        DarkCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Upcoming', Icons.event_rounded, d.accent),
            const SizedBox(height: 12),
            _EventRow('Assignment Due',  'Chapters 3–5 summary',   '2 days', Colors.orange,     Icons.assignment_outlined),
            _EventRow('Mid-Term Test',   'Topics 1–8 covered',     '5 days', Colors.redAccent,  Icons.quiz_outlined),
            _EventRow('Guest Lecture',   'Industry expert session', '1 week', d.accent,          Icons.record_voice_over_outlined),
          ],
        )),
        const SizedBox(height: 14),

        // ── Reminders ────────────────────────────────────────────────────
        DarkCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Reminders & Alerts', Icons.notifications_active_rounded,
                Colors.orange),
            const SizedBox(height: 10),
            _AlertRow('Pending submission from 4 students', Colors.orange),
            _AlertRow('Attendance below 75% — 2 students',  Colors.redAccent),
            _AlertRow('New resource awaiting CR approval',   const Color(0xFF7C4DFF)),
          ],
        )),
        const SizedBox(height: 14),

        // ── Smart Feed ───────────────────────────────────────────────────
        _SmartFeedCard(accent: d.accent),

      ],
    );
  }
}

// ── XP Level card ─────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final int level, xp; final double xpToNext;
  final Color accent; final Animation<double> barAnim;
  const _LevelCard({required this.level, required this.xp, required this.xpToNext,
    required this.accent, required this.barAnim});

  @override
  Widget build(BuildContext context) {
    final pct = xp / xpToNext;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            accent.withOpacity(0.12),
          ],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // ── IMAGE PLACEHOLDER 2 ────────────────────────────────────────
          // Replace error state with: Assets/images/level_badge.png
          // Ideal: 64×64 circular badge PNG, transparent background
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accent, accent.withOpacity(0.3)]),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 14)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lv', style: TextStyle(color: Colors.white.withOpacity(0.7),
                    fontSize: 9, fontWeight: FontWeight.w600)),
                Text('$level', style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Class Level $level',
                      style: const TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  Text('$xp / ${xpToNext.toInt()} XP',
                      style: TextStyle(color: accent, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                AnimatedBuilder(animation: barAnim, builder: (_, __) =>
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct * barAnim.value,
                        backgroundColor: Colors.white.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(accent),
                        minHeight: 7,
                      ),
                    ),
                ),
                const SizedBox(height: 6),
                Text('${(xpToNext - xp).toInt()} XP to Level ${level + 1}',
                    style: TextStyle(color: Colors.white.withOpacity(0.38),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Smart Feed card ───────────────────────────────────────────────────────────
class _SmartFeedCard extends StatelessWidget {
  final Color accent;
  const _SmartFeedCard({required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF12121F)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(
                color: const Color(0xFF7C4DFF).withOpacity(0.2))),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF7C4DFF), size: 16),
            const SizedBox(width: 8),
            const Text("Today's Smart Feed",
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('AI Summary',
                  style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeedItem(Icons.book_outlined,         'Lesson 8: Quadratic Equations covered.'),
              _FeedItem(Icons.assignment_outlined,   'Assignment 3 due in 2 days.'),
              _FeedItem(Icons.quiz_outlined,         'Mid-term in 5 days — revise Topics 1–8.'),
              _FeedItem(Icons.upload_file_outlined,  'New resource uploaded: Revision Sheet.'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FeedItem extends StatelessWidget {
  final IconData icon; final String text;
  const _FeedItem(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: const Color(0xFF7C4DFF).withOpacity(0.7)),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(color: Colors.white.withOpacity(0.62),
              fontSize: 13, height: 1.4))),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18,
        fontWeight: FontWeight.w800)),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3),
        fontSize: 9)),
  ]));
}

class _StatBox extends StatelessWidget {
  final String value, label; final IconData icon; final Color color;
  const _StatBox(this.value, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF161625),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontSize: 18,
          fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3),
          fontSize: 9)),
    ]),
  );
}

class _EventRow extends StatelessWidget {
  final String title, desc, when; final Color color; final IconData icon;
  const _EventRow(this.title, this.desc, this.when, this.color, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
        Text(desc, style: TextStyle(
            color: Colors.white.withOpacity(0.35), fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(when, style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _AlertRow extends StatelessWidget {
  final String text; final Color color;
  const _AlertRow(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(
          color: color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(
          color: Colors.white.withOpacity(0.55), fontSize: 12))),
    ]),
  );
}