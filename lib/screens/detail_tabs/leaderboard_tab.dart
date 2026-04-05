import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../class_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LeaderboardTab — XP-based class leaderboard
// • Overall rank + weekly delta
// • Achievement badges per student
// • Anonymous mode toggle
// • Top-3 podium display
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardTab extends StatefulWidget {
  final ClassData data;
  const LeaderboardTab({super.key, required this.data});
  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab>
    with SingleTickerProviderStateMixin {

  bool _anonymous = false;
  String _filter  = 'All Time'; // 'All Time' | 'This Week'

  // Sample leaderboard data — in a real build, this comes from
  // the students list with their accumulated XP
  late List<_LeaderEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _sampleEntries();
  }

  List<_LeaderEntry> _sampleEntries() => [
    _LeaderEntry('Aditya Kumar',  425, 80,  ['🏆','🔥','⭐'],  true),
    _LeaderEntry('Sneha Patel',   380, 60,  ['⭐','📚'],        false),
    _LeaderEntry('Priya Singh',   310, 45,  ['📚','💡'],        false),
    _LeaderEntry('Rohan Das',     275, 30,  ['💡'],             false),
    _LeaderEntry('Ananya Bose',   240, 55,  ['🔥','💡'],        false),
    _LeaderEntry('Vikram Rao',    185, 20,  ['📚'],             false),
    _LeaderEntry('Ishaan Mehta',  160, 10,  [],                 false),
    _LeaderEntry('Deepa Nair',    140, 35,  ['💡'],             false),
  ];

  List<_LeaderEntry> get _sorted {
    final l = List<_LeaderEntry>.from(_entries);
    if (_filter == 'This Week') {
      l.sort((a, b) => b.weekXp.compareTo(a.weekXp));
    } else {
      l.sort((a, b) => b.totalXp.compareTo(a.totalXp));
    }
    return l;
  }

  String _displayName(_LeaderEntry e, int idx) =>
      _anonymous ? 'Student #${idx + 1}' : e.name;

  @override
  Widget build(BuildContext context) {
    final d      = widget.data;
    final sorted = _sorted;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: Column(children: [

          // ── Header controls ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              // Filter chips
              _FilterChip('All Time', d.accent,
                  _filter == 'All Time',
                      () => setState(() => _filter = 'All Time')),
              const SizedBox(width: 8),
              _FilterChip('This Week', Colors.orange,
                  _filter == 'This Week',
                      () => setState(() => _filter = 'This Week')),
              const Spacer(),
              // Anonymous toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _anonymous = !_anonymous);
                },
                child: Container(
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
                    Icon(_anonymous ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                        size: 12, color: _anonymous
                            ? const Color(0xFF7C4DFF) : Colors.white38),
                    const SizedBox(width: 4),
                    Text(_anonymous ? 'Anonymous' : 'Named',
                        style: TextStyle(
                            color: _anonymous
                                ? const Color(0xFF7C4DFF) : Colors.white38,
                            fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Podium (top 3) ───────────────────────────────────────────
          if (sorted.length >= 3)
            _Podium(
              first:  sorted[0],
              second: sorted[1],
              third:  sorted[2],
              accent: d.accent,
              anonymous: _anonymous,
            ),

          const SizedBox(height: 8),

          // ── Divider label ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('FULL RANKINGS',
                    style: TextStyle(color: Colors.white.withOpacity(0.25),
                        fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
            ]),
          ),
        ])),

        // ── Full list ─────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (_, i) => _RankTile(
              entry:     sorted[i],
              rank:      i + 1,
              accent:    d.accent,
              color:     d.color,
              showWeek:  _filter == 'This Week',
              name:      _displayName(sorted[i], i),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Podium widget ─────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  final _LeaderEntry first, second, third;
  final Color accent;
  final bool  anonymous;
  const _Podium({required this.first, required this.second,
    required this.third, required this.accent, required this.anonymous});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumBlock(
          entry: second, rank: 2, height: 100,
          color: const Color(0xFFC0C0C0),
          name: anonymous ? 'Student #2' : second.name,
        )),
        const SizedBox(width: 8),
        Expanded(child: _PodiumBlock(
          entry: first, rank: 1, height: 130,
          color: const Color(0xFFFFD700),
          name: anonymous ? 'Student #1' : first.name,
        )),
        const SizedBox(width: 8),
        Expanded(child: _PodiumBlock(
          entry: third, rank: 3, height: 80,
          color: const Color(0xFFCD7F32),
          name: anonymous ? 'Student #3' : third.name,
        )),
      ],
    ),
  );
}

class _PodiumBlock extends StatelessWidget {
  final _LeaderEntry entry; final int rank; final double height;
  final Color color; final String name;
  const _PodiumBlock({required this.entry, required this.rank,
    required this.height, required this.color, required this.name});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Avatar + crown
      Stack(alignment: Alignment.topCenter, children: [
        if (rank == 1)
          const Text('👑', style: TextStyle(fontSize: 18)),
        Padding(
          padding: EdgeInsets.only(top: rank == 1 ? 18 : 0),
          child: CircleAvatar(
            radius: rank == 1 ? 26 : 20,
            backgroundColor: color.withOpacity(0.2),
            child: Text(name[0],
                style: TextStyle(color: color,
                    fontSize: rank == 1 ? 18 : 14,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(name, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10,
              fontWeight: FontWeight.w600)),
      Text('${entry.totalXp} XP',
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      // Podium bar
      Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border(top: BorderSide(color: color.withOpacity(0.5), width: 2)),
        ),
        child: Center(child: Text('#$rank',
            style: TextStyle(color: color, fontSize: 18,
                fontWeight: FontWeight.w900))),
      ),
    ],
  );
}

// ── Rank tile ─────────────────────────────────────────────────────────────────
class _RankTile extends StatelessWidget {
  final _LeaderEntry entry; final int rank;
  final Color accent, color; final bool showWeek; final String name;
  const _RankTile({required this.entry, required this.rank,
    required this.accent, required this.color, required this.showWeek,
    required this.name});

  Color get _rankColor => switch (rank) {
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
      color: rank <= 3
          ? _rankColor.withOpacity(0.05)
          : const Color(0xFF161625),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: rank <= 3
          ? _rankColor.withOpacity(0.25) : Colors.white.withOpacity(0.06)),
    ),
    child: Row(children: [
      // Rank number
      SizedBox(width: 28,
          child: Text('#$rank',
              textAlign: TextAlign.center,
              style: TextStyle(color: _rankColor, fontSize: 14,
                  fontWeight: FontWeight.w900))),
      const SizedBox(width: 10),
      // Avatar
      CircleAvatar(radius: 18, backgroundColor: accent.withOpacity(0.15),
          child: Text(name[0], style: TextStyle(color: accent,
              fontWeight: FontWeight.w800))),
      const SizedBox(width: 12),
      // Name + badges
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600)),
            if (entry.badges.isNotEmpty)
              Text(entry.badges.join(' '), style: const TextStyle(fontSize: 12)),
          ])),
      // XP display
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(showWeek ? '+${entry.weekXp}' : '${entry.totalXp}',
            style: TextStyle(color: accent, fontSize: 14,
                fontWeight: FontWeight.w800)),
        Text(showWeek ? 'this week' : 'total XP',
            style: TextStyle(color: Colors.white.withOpacity(0.3),
                fontSize: 9)),
      ]),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label; final Color color; final bool selected;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.color, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.15) : const Color(0xFF1E1E32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected
            ? color.withOpacity(0.45) : Colors.white.withOpacity(0.08)),
      ),
      child: Text(label,
          style: TextStyle(color: selected ? color : Colors.white38,
              fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}

class _LeaderEntry {
  final String       name;
  final int          totalXp, weekXp;
  final List<String> badges;
  final bool         isCR;
  const _LeaderEntry(this.name, this.totalXp, this.weekXp,
      this.badges, this.isCR);
}