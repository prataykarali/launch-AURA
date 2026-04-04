import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/class_card.dart';
import '../widgets/aura_subject_overlay.dart';
import '../widgets/add_class_sheet.dart';
import 'class_detail_page.dart';
import 'class_data.dart';

class ClassScreen extends StatefulWidget {
  const ClassScreen({super.key});
  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen>
    with SingleTickerProviderStateMixin {

  final List<ClassData> _classes = [
    ClassData(
      name: 'Advanced Mathematics', section: 'Grade 10 · Section A',
      subject: 'Maths',   teacher: 'Mr. Sharma', students: 34,
      color: const Color(0xFF1565C0), accent: const Color(0xFF64B5F6),
      icon: Icons.calculate_rounded,
    ),
    ClassData(
      name: 'Physics Lab', section: 'Grade 11 · Section B',
      subject: 'Science', teacher: 'Ms. Roy', students: 28,
      color: const Color(0xFF00695C), accent: const Color(0xFF4DD0C4),
      icon: Icons.science_rounded,
    ),
    ClassData(
      name: 'Creative Arts', section: 'Grade 9 · Section C',
      subject: 'Art', teacher: 'Mrs. Das', students: 22,
      color: const Color(0xFF6A1B9A), accent: const Color(0xFFCE93D8),
      icon: Icons.brush_rounded,
    ),
  ];

  bool _overlayOpen = false;

  late final AnimationController _pulse;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClassSheet(
        onSubmit: (data) {
          setState(() => _classes.insert(0, data));
          Navigator.pop(context);
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      body: Stack(
        children: [
          // ── Main scroll ───────────────────────────────────────────────
          CustomScrollView(
            // ADD AlwaysScrollableScrollPhysics to ensure stretch works even with few items
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _BannerBar(onBack: () => Navigator.of(context).pop()),
              _StatsRow(classes: _classes),
              _SectionLabel(label: 'YOUR CLASSES'),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.builder(
                  itemCount: _classes.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ClassCard(
                      data: _classes[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ClassDetailPage(data: _classes[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ── AURA overlay ─────────────────────────────────────────────
          AuraSubjectOverlay(
            open: _overlayOpen,
            onClose: () => setState(() => _overlayOpen = false),
          ),
        ],
      ),

      floatingActionButton: _overlayOpen ? null : _buildFabs(),
    );
  }

  Widget _buildFabs() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      ScaleTransition(
        scale: _pulseAnim,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _overlayOpen = true);
          },
          child: Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.6),
                  blurRadius: 22, spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'Assets/images/circle_detect_AURA.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF3F51B5)],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      FloatingActionButton.extended(
        heroTag: 'newclass',
        onPressed: _openAddSheet,
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Class',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      ),
    ],
  );
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _BannerBar extends StatelessWidget {
  final VoidCallback onBack;
  const _BannerBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return SliverAppBar(
      expandedHeight:  sw * 0.62,
      collapsedHeight: 56,
      pinned:          true,
      stretch:         true, // <--- CHANGED TO TRUE
      backgroundColor: const Color(0xFF0D0D18),
      elevation:       0,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: onBack,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        _AppBarBtn(icon: Icons.search_rounded),
        _AppBarBtn(icon: Icons.more_vert_rounded),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [
          StretchMode.zoomBackground, // <--- ADDED ZOOM EFFECT
        ],
        background: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'Assets/images/class_AURA.png',
                fit: BoxFit.cover, // <--- CHANGED FROM fill TO cover
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A237E),
                  child: const Center(child: Icon(Icons.school_rounded,
                      color: Colors.white24, size: 64)),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.65),
                      const Color(0xFF0D0D18),
                    ],
                    stops: const [0.0, 0.5, 0.82, 1.0],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 20, right: 20, bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CLASS SYNC',
                    style: TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: 3.0,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                  SizedBox(height: 3),
                  Text("The Modern Teacher's Hub",
                      style: TextStyle(
                          color: Color(0xAAFFFFFF), fontSize: 13, letterSpacing: 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  const _AppBarBtn({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
    decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
    child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20), onPressed: () {}),
  );
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<ClassData> classes;
  const _StatsRow({required this.classes});
  @override
  Widget build(BuildContext context) {
    final s = classes.fold(0, (a, c) => a + c.students);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(children: [
          _Chip(Icons.class_rounded,  '${classes.length} Classes', const Color(0xFF5C6BC0)),
          const SizedBox(width: 10),
          _Chip(Icons.people_rounded, '$s Students',               const Color(0xFF26A69A)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color), const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.3), letterSpacing: 2.0)),
    ),
  );
}