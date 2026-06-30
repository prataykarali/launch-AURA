part of 'class_screen.dart';

class _ClassScreenBody extends StatelessWidget {
  final List<ClassData> classes;
  final List<ClassData> filtered;
  final bool loading;
  final bool searchActive;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool overlayOpen;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onShare;
  final VoidCallback onMenu;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCloseOverlay;
  final ValueChanged<ClassData> onClassTap;
  final ValueChanged<ClassData> onClassDelete;

  const _ClassScreenBody({
    required this.classes,
    required this.filtered,
    required this.loading,
    required this.searchActive,
    required this.searchQuery,
    required this.searchCtrl,
    required this.overlayOpen,
    required this.onBack,
    required this.onSearch,
    required this.onShare,
    required this.onMenu,
    required this.onSearchChanged,
    required this.onCloseOverlay,
    required this.onClassTap,
    required this.onClassDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_classBgTop, _classBgMid, _classBgBottom],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _ClassroomBackdrop()),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _BannerBar(
                onBack: onBack,
                onSearch: onSearch,
                onShare: onShare,
                onMenu: onMenu,
                searchActive: searchActive,
                searchCtrl: searchCtrl,
                onSearchChanged: onSearchChanged,
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatsRow(classes: classes),
                        if (searchActive && searchQuery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${filtered.length} result'
                                '${filtered.length == 1 ? "" : "s"}'
                                ' for "$searchQuery"',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          _SectionLabel(label: 'YOUR CLASSES'),
                      ],
                    ),
                  ),
                ),
              ),
              if (loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF5C6BC0),
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No classes yet... Click + to create one!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _ClassList(
                  filtered: filtered,
                  onClassTap: onClassTap,
                  onClassDelete: onClassDelete,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (overlayOpen)
            _AiOverlay(onClose: onCloseOverlay),
        ],
      ),
    );
  }
}
