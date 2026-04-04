import 'package:flutter/material.dart';
import 'class_data.dart';

// ── Tab imports — paths match lib/screens/detail_tabs/ ──────────────────────
import 'detail_tabs/overview_tab.dart';
import 'detail_tabs/lessons_tab.dart';
import 'detail_tabs/resources_tab.dart';
import 'detail_tabs/students_tab.dart';
import 'detail_tabs/stream_tab.dart';

class ClassDetailPage extends StatefulWidget {
  final ClassData data;
  const ClassDetailPage({super.key, required this.data});
  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_DetailHeader(data: d, tabs: _tabs)],
        body: TabBarView(
          controller: _tabs,
          children: [
            OverviewTab(data: d),
            LessonsTab(data: d),
            ResourcesTab(data: d),
            StudentsTab(data: d),
            StreamTab(data: d),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _DetailHeader extends StatelessWidget {
  final ClassData data;
  final TabController tabs;
  const _DetailHeader({required this.data, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: d.color,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        _HBtn(Icons.edit_outlined),
        _HBtn(Icons.share_outlined),
        _HBtn(Icons.more_vert_rounded),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(fit: StackFit.expand, children: [
          // IMAGE PLACEHOLDER: Assets/images/subject_banner_default.png
          Image.asset(
            'Assets/images/subject_banner_${d.subject.toLowerCase()}.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [d.color, Color.lerp(d.color, Colors.black, 0.45)!],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: d.accent.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: d.accent.withOpacity(0.4)),
                    ),
                    child: Text(d.subject.toUpperCase(),
                        style: TextStyle(color: d.accent, fontSize: 9.5,
                            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  ),
                  const SizedBox(height: 8),
                  Text(d.name,
                      style: const TextStyle(color: Colors.white, fontSize: 21,
                          fontWeight: FontWeight.w900, height: 1.15)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.people_outline_rounded, size: 12,
                        color: Colors.white54),
                    const SizedBox(width: 5),
                    Text('${d.students} students  ·  ${d.teacher}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
      bottom: TabBar(
        controller: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Lessons'),
          Tab(text: 'Resources'),
          Tab(text: 'Students'),
          Tab(text: 'Stream'),
        ],
      ),
    );
  }
}

class _HBtn extends StatelessWidget {
  final IconData icon;
  const _HBtn(this.icon);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
    decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25), shape: BoxShape.circle),
    child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 17), onPressed: () {}),
  );
}