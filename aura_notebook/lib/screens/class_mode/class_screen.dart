import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'class_main_widgets/class_card.dart';
import 'class_main_widgets/aura_subject_overlay.dart';
import 'class_main_widgets/add_class_sheet.dart';
import 'class_pages/class_detail_page.dart';
import 'class_pages/class_data.dart';
import 'package:aura_notebook/utils/responsive.dart';

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

  bool    _overlayOpen   = false;
  bool    _searchActive  = false;
  String  _searchQuery   = '';
  final   _searchCtrl    = TextEditingController();

  late final AnimationController _pulse;
  late final Animation<double>   _pulseAnim;

  List<ClassData> get _filtered {
    if (_searchQuery.isEmpty) return _classes;
    final q = _searchQuery.toLowerCase();
    return _classes.where((c) =>
    c.name.toLowerCase().contains(q)    ||
        c.subject.toLowerCase().contains(q) ||
        c.teacher.toLowerCase().contains(q) ||
        c.section.toLowerCase().contains(q)
    ).toList();
  }

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
  void dispose() {
    _pulse.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.of(context).pop();

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) { _searchQuery = ''; _searchCtrl.clear(); }
    });
  }

  void _share() {
    final summary = _classes.map((c) =>
    '${c.name} (${c.subject}) — ${c.teacher}').join('\n');
    Clipboard.setData(ClipboardData(
        text: 'My ClassSync Classes:\n\n$summary'));
    ScaffoldMessenger.of(context).showSnackBar(_snack('Class list copied to clipboard!'));
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuSheet(
        onSort:   () { Navigator.pop(context); _sortClasses(); },
        onFilter: () { Navigator.pop(context); _showSnackMsg('Filter coming soon'); },
        onExport: () { Navigator.pop(context); _share(); },
        onAbout:  () { Navigator.pop(context); _showSnackMsg('AURA ClassSync v1.0'); },
      ),
    );
  }

  void _sortClasses() {
    setState(() => _classes.sort((a, b) => a.name.compareTo(b.name)));
    ScaffoldMessenger.of(context).showSnackBar(_snack('Sorted A → Z'));
  }

  void _showSnackMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(_snack(msg));

  SnackBar _snack(String msg) => SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    backgroundColor: const Color(0xFF1A1A2E),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  );

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

  void _confirmDelete(ClassData c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Class',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text('Delete "${c.name}"?\nThis cannot be undone.',
            style: TextStyle(color: Colors.white70,
                fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              setState(() => _classes.remove(c));
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                  _snack('${c.name} deleted'));
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0D0D18),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _BannerBar(
                onBack:          _goBack,
                onSearch:        _toggleSearch,
                onShare:         _share,
                onMenu:          _showMenu,
                searchActive:    _searchActive,
                searchCtrl:      _searchCtrl,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
              ),

              _StatsRow(classes: _classes),

              if (_searchActive && _searchQuery.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                        '${_filtered.length} result'
                            '${_filtered.length == 1 ? "" : "s"}'
                            ' for "$_searchQuery"',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12)),
                  ),
                )
              else
                _SectionLabel(label: 'YOUR CLASSES'),

              if (_filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      Icon(Icons.search_off_rounded, size: 48,
                          color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('No classes match your search',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3))),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ClassCard(
                        data: _filtered[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassDetailPage(data: _filtered[i]),
                          ),
                        ),
                        onDelete: () => _confirmDelete(_filtered[i]),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // ✅ FIX: Mount overlay only when open so it cannot block taps while closed.
          if (_overlayOpen)
            AuraSubjectOverlay(
              open: true,
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
              boxShadow: [BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.6),
                blurRadius: 22, spreadRadius: 2,
              )],
            ),
            child: ClipOval(
              child: Image.asset(
                'Assets/images/circle_detect_AURA.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFF3F51B5)]),
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
        heroTag:         'newclass',
        onPressed:       _openAddSheet,
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        elevation:       8,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('New Class',
            style: TextStyle(fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// BANNER BAR — stretchy parallax, working buttons, inline search
// ═════════════════════════════════════════════════════════════════════════════
class _BannerBar extends StatelessWidget {
  final VoidCallback            onBack, onShare, onMenu;
  final VoidCallback            onSearch;
  final bool                    searchActive;
  final TextEditingController   searchCtrl;
  final ValueChanged<String>    onSearchChanged;

  const _BannerBar({
    required this.onBack,
    required this.onSearch,
    required this.onShare,
    required this.onMenu,
    required this.searchActive,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return SliverAppBar(
      expandedHeight: R.isDesktop ? 280 : sw * 0.60,
      collapsedHeight: 56,
      pinned: true,
      snap: false,
      floating: false,
      stretch: true,
      backgroundColor: const Color(0xFF0D0D18),
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: onBack,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      title: searchActive
          ? _SearchBar(ctrl: searchCtrl, onChanged: onSearchChanged)
          : null,
      actions: [
        if (!searchActive)
          _AppBarBtn(icon: Icons.search_rounded,   onTap: onSearch)
        else
          _AppBarBtn(icon: Icons.close_rounded,    onTap: onSearch),
        _AppBarBtn(icon: Icons.share_rounded,      onTap: onShare),
        _AppBarBtn(icon: Icons.more_vert_rounded,  onTap: onMenu),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'Assets/images/class_AURA.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A237E),
                child: const Center(
                    child: Icon(Icons.school_rounded,
                        color: Colors.white24, size: 64)),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.60),
                    const Color(0xFF0D0D18),
                  ],
                  stops: const [0.0, 0.45, 0.80, 1.0],
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
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                  SizedBox(height: 3),
                  Text("The Modern Teacher's Hub",
                      style: TextStyle(
                          color: Color(0xAAFFFFFF),
                          fontSize: 13,
                          letterSpacing: 0.4)),
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
  final IconData icon; final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      width:  40, height: 40,
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.42), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    onChanged: onChanged,
    autofocus: true,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      hintText: 'Search classes…',
      hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
      border: InputBorder.none,
    ),
  );
}

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
          _Chip(Icons.class_rounded,  '${classes.length} Classes',
              const Color(0xFF5C6BC0)),
          const SizedBox(width: 10),
          _Chip(Icons.people_rounded, '$s Students',
              const Color(0xFF26A69A)),
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
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(24),
      border:       Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
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
              color: Colors.white30, letterSpacing: 2.0)),
    ),
  );
}

class _MenuSheet extends StatelessWidget {
  final VoidCallback onSort, onFilter, onExport, onAbout;
  const _MenuSheet({required this.onSort, required this.onFilter,
    required this.onExport, required this.onAbout});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16),
    decoration: const BoxDecoration(
      color: Color(0xFF12121F),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 16),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2)))),
      _MenuItem(Icons.sort_by_alpha_rounded, 'Sort A → Z',       onSort),
      _MenuItem(Icons.filter_list_rounded,   'Filter by Subject', onFilter),
      _MenuItem(Icons.share_rounded,         'Share Class List',  onExport),
      _MenuItem(Icons.info_outline_rounded,  'About ClassSync',   onAbout),
      const SizedBox(height: 8),
    ]),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: const Color(0xFF5C6BC0), size: 20),
    title: Text(label, style: const TextStyle(color: Colors.white,
        fontSize: 14, fontWeight: FontWeight.w600)),
    onTap: onTap,
  );
}