part of 'class_screen.dart';

class _BannerBar extends StatelessWidget {
  final VoidCallback onBack, onShare, onMenu;
  final VoidCallback onSearch;
  final bool searchActive;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

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
      expandedHeight: R.isDesktop ? 300 : sw * 0.54,
      collapsedHeight: 64,
      pinned: true,
      stretch: true,
      backgroundColor: _classBgTop,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Center(
        child: _AppBarBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
      ),
      title: searchActive
          ? _SearchBar(ctrl: searchCtrl, onChanged: onSearchChanged)
          : null,
      actions: [
        if (!searchActive)
          _AppBarBtn(icon: Icons.search_rounded, onTap: onSearch)
        else
          _AppBarBtn(icon: Icons.close_rounded, onTap: onSearch),
        _AppBarBtn(icon: Icons.share_rounded, onTap: onShare),
        _AppBarBtn(icon: Icons.more_vert_rounded, onTap: onMenu),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'Assets/images/class_AURA.png',
              fit: R.isDesktop ? BoxFit.fitWidth : BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A237E),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white24,
                    size: 64,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.50),
                    _classBgMid,
                  ],
                  stops: const [0.0, 0.45, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CLASS SYNC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 10),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "The Modern Teacher's Hub",
                          style: TextStyle(
                            color: Color(0xAAFFFFFF),
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
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
