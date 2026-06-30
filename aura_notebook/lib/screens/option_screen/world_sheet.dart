part of 'option_screen.dart';

class _WorldSheet extends StatefulWidget {
  final VoidCallback onAura, onClass, onInfo;
  const _WorldSheet({required this.onAura, required this.onClass, required this.onInfo});

  @override
  State<_WorldSheet> createState() => _WorldSheetState();
}

class _WorldSheetState extends State<_WorldSheet> with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnim(int index) => CurvedAnimation(
    parent: _staggerCtrl,
    curve: Interval(index * 0.15, 0.6 + index * 0.15, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      const Text(
                        'Choose Your World',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where do you want to go?',
                        style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13),
                      ),
                    ],
                  ),
                ),

                FadeTransition(
                  opacity: _itemAnim(0),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_itemAnim(0)),
                    child: _WorldCard(
                      assetPath: 'Assets/images/AURA_load.png',
                      title: 'AURA NOTEBOOK',
                      subtitle: 'Your personal AI companion',
                      accent: const Color(0xFFFF3CAC),
                      icon: Icons.auto_awesome_rounded,
                      onTap: widget.onAura,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                FadeTransition(
                  opacity: _itemAnim(1),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_itemAnim(1)),
                    child: _WorldCard(
                      assetPath: 'Assets/images/class_AURA.png',
                      title: 'CLASS SYNC',
                      subtitle: "The Modern Teacher's Hub",
                      accent: const Color(0xFF00B0FF),
                      icon: Icons.school_rounded,
                      onTap: widget.onClass,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                FadeTransition(
                  opacity: _itemAnim(2),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_itemAnim(2)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: widget.onInfo,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161625),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'About AURA',
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'Version, credits & info',
                                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.25)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
