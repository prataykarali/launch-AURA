import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardTab — self-contained scrollable leaderboard.
// Used inside a bottom sheet from OverviewTab.
// Dark background, no white Card wrapper.
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardTab extends StatefulWidget {
  final ClassData data;
  const LeaderboardTab({super.key, required this.data});
  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {

  bool   _anonymous = false;
  String _filter    = 'All Time';

  final List<_LeaderEntry> _entries = [
    _LeaderEntry('Aditya Kumar',  425, 80,  ['🏆', '🔥', '⭐'], isCR: true),
    _LeaderEntry('Sneha Patel',   380, 60,  ['⭐', '📚']),
    _LeaderEntry('Priya Singh',   310, 45,  ['📚', '💡']),
    _LeaderEntry('Rohan Das',     275, 30,  ['💡']),
    _LeaderEntry('Ananya Bose',   240, 55,  ['🔥', '💡']),
    _LeaderEntry('Vikram Rao',    185, 20,  ['📚']),
    _LeaderEntry('Ishaan Mehta',  160, 10,  []),
    _LeaderEntry('Deepa Nair',    140, 35,  ['💡']),
  ];

  List<_LeaderEntry> get _sorted {
    final l = List<_LeaderEntry>.from(_entries);
    l.sort((a, b) => _filter == 'This Week'
        ? b.weekXp.compareTo(a.weekXp)
        : b.totalXp.compareTo(a.totalXp));
    return l;
  }

  String _name(_LeaderEntry e, int idx) =>
      _anonymous ? 'Student #${idx + 1}' : e.name;

  @override
  Widget build(BuildContext context) {
    final d      = widget.data;
    final sorted = _sorted;

    return Column(children: [
      // ── Controls ──────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          _FChip('All Time',  d.accent,  _filter == 'All Time',
                  () => setState(() => _filter = 'All Time')),
          const SizedBox(width: 8),
          _FChip('This Week', Colors.orange, _filter == 'This Week',
                  () => setState(() => _filter = 'This Week')),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _anonymous = !_anonymous);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _anonymous
                    ? const Color(0xFF7C4DFF).withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _anonymous
                    ? const Color(0xFF7C4DFF).withOpacity(0.4)
                    : Colors.white.withOpacity(0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_anonymous
                    ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 12,
                    color: _anonymous
                        ? const Color(0xFF7C4DFF) : Colors.white38),
                const SizedBox(width: 4),
                Text(_anonymous ? 'Anon' : 'Named',
                    style: TextStyle(
                        color: _anonymous
                            ? const Color(0xFF7C4DFF) : Colors.white38,
                        fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),

      // ── Podium ────────────────────────────────────────────────────────
      if (sorted.length >= 3)
        _Podium(
          first:     sorted[0],
          second:    sorted[1],
          third:     sorted[2],
          accent:    d.accent,
          anonymous: _anonymous,
        ),

      // ── Divider ───────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SizedBox(width: 16),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('FULL RANKINGS',
                style: TextStyle(color: Colors.white.withOpacity(0.22),
                    fontSize: 9, fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
          const SizedBox(width: 16),
        ]),
      ),

      // ── Ranked list ───────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _RankTile(
            e: sorted[i],          // Changed 'entry' to 'e'
            rank: i + 1,
            name: sorted[i].name,  // Add missing required parameter
            accent: Colors.blue,   // Add missing required parameter (or your specific color)
            color: Colors.white,   // Add missing required parameter
            showWeek: true,        // Add missing required parameter
          ),
        ),
      ),
    ]);
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final _LeaderEntry first, second, third;
  final Color accent; final bool anonymous;
  const _Podium({required this.first, required this.second,
    required this.third, required this.accent, required this.anonymous});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: _PBlock(second, 2, 90,  const Color(0xFFC0C0C0),
          anonymous ? 'Student #2' : second.name)),
      const SizedBox(width: 8),
      Expanded(child: _PBlock(first,  1, 120, const Color(0xFFFFD700),
          anonymous ? 'Student #1' : first.name)),
      const SizedBox(width: 8),
      Expanded(child: _PBlock(third,  3, 70,  const Color(0xFFCD7F32),
          anonymous ? 'Student #3' : third.name)),
    ]),
  );
}

class _PBlock extends StatelessWidget {
  final _LeaderEntry e; final int rank; final double h;
  final Color color; final String name;
  const _PBlock(this.e, this.rank, this.h, this.color, this.name);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (rank == 1) const Text('👑', style: TextStyle(fontSize: 16)),
      Padding(
        padding: EdgeInsets.only(top: rank == 1 ? 0 : 16),
        child: CircleAvatar(
            radius: rank == 1 ? 24 : 18,
            backgroundColor: color.withOpacity(0.2),
            child: Text(name[0], style: TextStyle(color: color,
                fontSize: rank == 1 ? 16 : 12,
                fontWeight: FontWeight.w900))),
      ),
      const SizedBox(height: 4),
      Text(name, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.w600)),
      Text(
          _filter(e),
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Container(
        height: h, width: double.infinity,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(top: BorderSide(color: color.withOpacity(0.5), width: 2))),
        child: Center(child: Text('#$rank', style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.w900))),
      ),
    ],
  );

  // can't access outer state, show total XP
  String _filter(_LeaderEntry entry) => '${entry.totalXp} XP';
}

// ── Rank tile ─────────────────────────────────────────────────────────────────
class _RankTile extends StatelessWidget {
  final _LeaderEntry e; final int rank;
  final Color accent, color; final bool showWeek; final String name;
  const _RankTile({required this.e, required this.rank,
    required this.accent, required this.color, required this.showWeek,
    required this.name});

  Color get _rc => switch (rank) {
    1 => const Color(0xFFFFD700),
    2 => const Color(0xFFC0C0C0),
    3 => const Color(0xFFCD7F32),
    _ => Colors.white38,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
        color: rank <= 3 ? _rc.withOpacity(0.05) : const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rank <= 3
            ? _rc.withOpacity(0.25) : Colors.white.withOpacity(0.06))),
    child: Row(children: [
      SizedBox(width: 28, child: Text('#$rank', textAlign: TextAlign.center,
          style: TextStyle(color: _rc, fontSize: 14,
              fontWeight: FontWeight.w900))),
      const SizedBox(width: 10),
      CircleAvatar(radius: 17, backgroundColor: accent.withOpacity(0.15),
          child: Text(name[0], style: TextStyle(color: accent,
              fontWeight: FontWeight.w800))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(name, style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              if (e.isCR) ...[
                const SizedBox(width: 6),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('CR', style: TextStyle(
                        color: Color(0xFF7C4DFF), fontSize: 8,
                        fontWeight: FontWeight.w800))),
              ],
            ]),
            if (e.badges.isNotEmpty)
              Text(e.badges.join(' '),
                  style: const TextStyle(fontSize: 11)),
          ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(showWeek ? '+${e.weekXp}' : '${e.totalXp}',
            style: TextStyle(color: accent, fontSize: 14,
                fontWeight: FontWeight.w800)),
        Text(showWeek ? 'this week' : 'total XP',
            style: TextStyle(color: Colors.white.withOpacity(0.3),
                fontSize: 9)),
      ]),
    ]),
  );
}

class _FChip extends StatelessWidget {
  final String l; final Color c; final bool sel; final VoidCallback t;
  const _FChip(this.l, this.c, this.sel, this.t);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: t,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.15) : const Color(0xFF1E1E32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? c.withOpacity(0.45)
              : Colors.white.withOpacity(0.08))),
      child: Text(l, style: TextStyle(
          color: sel ? c : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}

class _LeaderEntry {
  final String name; final int totalXp, weekXp;
  final List<String> badges; final bool isCR;
  const _LeaderEntry(this.name, this.totalXp, this.weekXp, this.badges,
      {this.isCR = false});
}