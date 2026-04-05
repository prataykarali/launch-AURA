import 'package:flutter/material.dart';
import 'class_data.dart';
import 'student_model.dart';
import 'detail_tabs/overview_tab.dart';
import 'detail_tabs/lessons_tab.dart';
import 'detail_tabs/resources_tab.dart';
import 'detail_tabs/students_tab.dart';
import 'detail_tabs/stream_tab.dart';
import 'detail_tabs/attendance_tab.dart';

class ClassDetailPage extends StatefulWidget {
  final ClassData data;
  const ClassDetailPage({super.key, required this.data});
  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage>
    with TickerProviderStateMixin {

  late final TabController _tabs;
  final List<StudentModel> _students = [];
  int _externalXp = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _onStudentsChanged(List<StudentModel> updated) {
    setState(() {
      _students
        ..clear()
        ..addAll(updated);
    });
  }

  void _addXp(int xp) => setState(() => _externalXp += xp);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0D0D18),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _DetailHeader(data: d, tabs: _tabs),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            OverviewTab(
              data:        d,
              externalXp:  _externalXp.toDouble(), // Ensure this matches OverviewTab's expected type
              onXpEarned:  _addXp,
            ),
            LessonsTab(data: d),
            ResourcesTab(data: d),
            StudentsTab(
              data:             d,
              students:         _students,
              onStudentsChanged: _onStudentsChanged,
            ),
            AttendanceTab(
              data:     d,
              students: _students,
            ),
            StreamTab(data: d),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final ClassData     data;
  final TabController tabs;

  // FIX: Only one constructor is allowed. Removed the duplicate at the bottom.
  const _DetailHeader({required this.data, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final d     = data;
    // Note: ensure themeFor is defined in class_data.dart or imported
    final theme = themeFor(d.subject);

    return SliverAppBar(
      expandedHeight:  220,
      pinned:          true,
      stretch:         true,
      backgroundColor: const Color(0xFF0D0D18),
      elevation:       0,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(fit: StackFit.expand, children: [
          Image.asset(
            theme.bannerAsset,
            fit:       BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [d.color, Color.lerp(d.color, Colors.black, 0.45)!],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.65),
                  const Color(0xFF0D0D18),
                ],
                stops: const [0.0, 0.45, 0.78, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20, right: 20, bottom: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        d.accent.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: d.accent.withOpacity(0.4)),
                  ),
                  child: Text(d.subject.toUpperCase(),
                      style: TextStyle(color: d.accent, fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                ),
                const SizedBox(height: 8),
                Text(d.name,
                  style: const TextStyle(
                    color:      Colors.white, fontSize: 21,
                    fontWeight: FontWeight.w900, height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.people_outline_rounded, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    '${d.students} students  ·  ${d.section}  ·  ${d.teacher}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  )),
                ]),
              ],
            ),
          ),
        ]),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: const Color(0xFF0D0D18),
          child: TabBar(
            controller:            tabs,
            isScrollable:          true,
            tabAlignment:          TabAlignment.start,
            indicatorColor:        d.accent,
            indicatorWeight:       2.5,
            labelColor:            Colors.white,
            unselectedLabelColor:  Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Lessons'),
              Tab(text: 'Resources'),
              Tab(text: 'Students'),
              Tab(text: 'Attendance'),
              Tab(text: 'Stream'),
            ],
          ),
        ),
      ),
    );
  }
}