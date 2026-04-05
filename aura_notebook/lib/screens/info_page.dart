import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InfoPage — About / Credits / Features / Tech stack
//
// IMAGE PLACEHOLDER:
//   Assets/images/info_banner.png  → wide banner shown at top of page
//   Suggested: 1080×500, a dark cosmic/futuristic illustration
//   showing AI + education theme (robot teacher, stars, code snippets)
// ─────────────────────────────────────────────────────────────────────────────
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
  }

  @override
  void dispose() { _orbCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0D0D18),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero banner app bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned:         true,
            stretch:        true,
            backgroundColor: const Color(0xFF0D0D18),
            elevation:      0,
            automaticallyImplyLeading: false,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              collapseMode: CollapseMode.parallax,
              background: Stack(fit: StackFit.expand, children: [

                // ── IMAGE PLACEHOLDER ──────────────────────────────────
                // Replace with: Assets/images/info_banner.png
                // Size: 1080×500 px, dark AI/education illustration
                Image.asset(
                  'Assets/images/info_banner.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _FallbackBanner(
                      ctrl: _orbCtrl),
                ),

                // Gradient scrim
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.75),
                        const Color(0xFF0D0D18),
                      ],
                      stops: const [0.0, 0.4, 0.78, 1.0],
                    ),
                  ),
                ),

                // App identity at bottom
                Positioned(
                  left: 20, right: 20, bottom: 20,
                  child: Row(children: [
                    // Animated app icon
                    AnimatedBuilder(
                      animation: _orbCtrl,
                      builder: (_, __) => Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: SweepGradient(
                            transform: GradientRotation(
                                _orbCtrl.value * math.pi * 2),
                            colors: const [
                              Color(0xFF7C4DFF), Color(0xFF40C4FF),
                              Color(0xFF00E5FF), Color(0xFF7C4DFF),
                            ],
                          ),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF7C4DFF).withOpacity(0.5),
                            blurRadius: 16,
                          )],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AURA',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 28, fontWeight: FontWeight.w900,
                                  letterSpacing: 5)),
                          Text('Version 1.0.0  ·  Build 2025',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12)),
                        ]),
                  ]),
                ),
              ]),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: _InfoBody(orbCtrl: _orbCtrl),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Fallback banner when image not found ──────────────────────────────────────
class _FallbackBanner extends StatelessWidget {
  final AnimationController ctrl;
  const _FallbackBanner({required this.ctrl});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1A0A2E),
                const Color(0xFF0A1A3E), ctrl.value)!,
            const Color(0xFF0D0D18),
          ],
        ),
      ),
      child: Stack(children: [
        // Decorative orbs
        for (int i = 0; i < 3; i++)
          Positioned(
            left:  50.0 + i * 120,
            top:   20.0 + math.sin(ctrl.value * math.pi * 2 + i) * 30,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  [const Color(0xFF7C4DFF),
                    const Color(0xFF40C4FF),
                    const Color(0xFFFF3CAC)][i].withOpacity(0.3),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 48, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 8),
              Text('Add Assets/images/info_banner.png',
                  style: TextStyle(color: Colors.white.withOpacity(0.2),
                      fontSize: 11)),
            ])),
      ]),
    ),
  );
}

// ── Main info content ─────────────────────────────────────────────────────────
class _InfoBody extends StatelessWidget {
  final AnimationController orbCtrl;
  const _InfoBody({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Tagline card ──────────────────────────────────────────────────
      Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF7C4DFF).withOpacity(0.3)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(animation: orbCtrl, builder: (_, __) =>
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(const Color(0xFFFF3CAC),
                        const Color(0xFF7C4DFF), orbCtrl.value),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF7C4DFF).withOpacity(0.6),
                        blurRadius: 8)],
                  ),
                ),
            ),
            const SizedBox(width: 10),
            const Text('AI-Powered Academic Companion',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            AnimatedBuilder(animation: orbCtrl, builder: (_, __) =>
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(const Color(0xFF7C4DFF),
                        const Color(0xFFFF3CAC), orbCtrl.value),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF40C4FF).withOpacity(0.6),
                        blurRadius: 8)],
                  ),
                ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'AURA combines a personal AI notebook with ClassSync — '
                'a full classroom management platform. Lesson planning, '
                'AI-generated summaries, XP gamification, attendance tracking, '
                'doubt queues, quizzes, and leaderboards — all offline, '
                'all on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13, height: 1.6),
          ),
        ]),
      ),

      // ── About ─────────────────────────────────────────────────────────
      _Section('ABOUT', [
        _InfoTile(Icons.info_outline_rounded,    'App Name',
            'AURA — AI Unified Resource Assistant'),
        _InfoTile(Icons.person_rounded,           'Developer',
            'Pratay Karali'),
        _InfoTile(Icons.school_outlined,          'Institute',
            'IEM Kolkata — CSE (AIML), Section 2A'),
        _InfoTile(Icons.badge_outlined,           'Roll No',
            '38  ·  Enrollment: 12024002028038'),
        _InfoTile(Icons.calendar_today_rounded,   'Academic Year',
            '2nd Year, 2024 – 2025'),
        _InfoTile(Icons.tag_rounded,              'Version',
            '1.0.0  ·  April 2025'),
      ]),

      const SizedBox(height: 20),

      // ── ClassSync features ────────────────────────────────────────────
      _Section('CLASSSYNC FEATURES', [
        _InfoTile(Icons.class_rounded,            'Class Management',
            'Create classes with 12 subject themes, codes, and banners'),
        _InfoTile(Icons.track_changes_rounded,    'Syllabus Tracker',
            'Interactive topic checklist with XP rewards per completion'),
        _InfoTile(Icons.quiz_rounded,             'AI Quiz Generator',
            'AURA writes 5 MCQs from your completed topics — earn up to 100 XP'),
        _InfoTile(Icons.help_outline_rounded,     'Doubt Queue',
            'Students post doubts — AURA answers first, escalate if needed'),
        _InfoTile(Icons.auto_awesome_rounded,     'Smart Briefing',
            'Auto-generated 3-bullet daily class summary on every open'),
        _InfoTile(Icons.leaderboard_rounded,      'Leaderboard',
            'XP rankings with podium, weekly delta, and anonymous mode'),
        _InfoTile(Icons.assignment_outlined,      'Assignment Tracker',
            'Post assignments with due-date countdowns and submission XP'),
        _InfoTile(Icons.how_to_reg_rounded,       'Attendance Register',
            'Date-picker register with per-student % and low-attendance alerts'),
        _InfoTile(Icons.menu_book_rounded,        'Lesson Planner',
            'Document topics, objectives, and assigned tasks per session'),
        _InfoTile(Icons.folder_rounded,           'Resource Hub',
            'Upload PDFs, PPTs, links with type-filter and download list'),
        _InfoTile(Icons.verified_outlined,        'CR Panel',
            'Class Representative verification queue and discussion threads'),
        _InfoTile(Icons.campaign_rounded,         'Class Stream',
            'Live post feed with CR-verified badges and instant messaging'),
      ]),

      const SizedBox(height: 20),

      // ── XP system ─────────────────────────────────────────────────────
      _Section('XP LEVEL SYSTEM', [
        _InfoTile(Icons.looks_one_rounded,        'Level 1 — Beginner',   '0 XP'),
        _InfoTile(Icons.looks_two_rounded,        'Level 2 — Learner',    '200 XP'),
        _InfoTile(Icons.looks_3_rounded,          'Level 3 — Rising',     '550 XP'),
        _InfoTile(Icons.looks_4_rounded,          'Level 4 — Skilled',    '1,050 XP'),
        _InfoTile(Icons.looks_5_rounded,          'Level 5 — Advanced',   '1,700 XP'),
        _InfoTile(Icons.looks_6_rounded,          'Level 6 — Expert',     '2,500 XP'),
        _InfoTile(Icons.star_rounded,             'Level 7 — Master',     '3,450 XP'),
        _InfoTile(Icons.emoji_events_rounded,     'Level 8 — Legend',     '4,550+ XP'),
      ]),

      const SizedBox(height: 20),

      // ── Technology ────────────────────────────────────────────────────
      _Section('TECHNOLOGY', [
        _InfoTile(Icons.flutter_dash,             'Frontend',
            'Flutter 3.41.x (Dart) — Material Design 3, dark-first UI'),
        _InfoTile(Icons.memory_rounded,           'AI Engine',
            'Python + llama-cpp-python — LFM2.5-1.2B GGUF (local, offline)'),
        _InfoTile(Icons.storage_rounded,          'Database',
            'SQLite 3 — all data on-device, zero cloud dependency'),
        _InfoTile(Icons.speed_rounded,            'AI Latency',
            'Sub-3 second first-token response on mid-range Android'),
        _InfoTile(Icons.animation_rounded,        'Performance',
            '60 FPS on all animated transitions, tested on Samsung A16 5G'),
        _InfoTile(Icons.lock_outline_rounded,     'Privacy',
            'No data leaves your device — ever'),
      ]),

      const SizedBox(height: 20),

      // ── Legal ─────────────────────────────────────────────────────────
      _Section('LEGAL', [
        _InfoTile(Icons.verified_user_rounded, 'Licence',
            'MIT — Open Source. Free to use and modify.'),
        _InfoTile(Icons.privacy_tip_outlined,     'Data Policy',
            'Zero external servers. All data stored locally on device.'),
        _InfoTile(Icons.model_training_rounded,   'AI Model',
            'LFM2.5-1.2B — open-weight model by Liquid AI, Inc.'),
        _InfoTile(Icons.copyright_rounded,        'Copyright',
            '© 2025 Pratay Karali. IEM Kolkata.'),
      ]),

      const SizedBox(height: 28),

      // ── Made with love card ───────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF7C4DFF).withOpacity(0.3)),
        ),
        child: Column(children: [
          const Text('❤️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          const Text('Made with passion at IEM Kolkata',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              'AURA started as a personal AI project and grew into a '
                  'full academic platform. Every feature was designed to '
                  'make teaching and learning just a little bit easier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12, height: 1.6)),
          const SizedBox(height: 16),
          // Tech badges
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              'Flutter', 'Python', 'SQLite',
              'LFM2.5', 'llama.cpp', 'Dart',
            ].map((t) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF7C4DFF).withOpacity(0.25)),
              ),
              child: Text(t, style: const TextStyle(
                  color: Color(0xFF9C7DFF), fontSize: 11,
                  fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ]),
      ),
    ]);
  }
}

// ── Section ───────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String label; final List<Widget> children;
  const _Section(this.label, this.children);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.28),
                fontSize: 10, fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: children.asMap().entries.map((e) => Column(
            children: [
              e.value,
              if (e.key < children.length - 1)
                Divider(height: 1, indent: 54,
                    color: Colors.white.withOpacity(0.05)),
            ],
          )).toList(),
        ),
      ),
    ],
  );
}

// ── Info tile ─────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF7C4DFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16,
            color: const Color(0xFF7C4DFF).withOpacity(0.75)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            color: Colors.white.withOpacity(0.35), fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w500, height: 1.3)),
      ])),
    ]),
  );
}