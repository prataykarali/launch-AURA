import 'package:flutter/material.dart';
import 'screens.dart'; // re-exports home, ClassScreen

// ─────────────────────────────────────────────────────────────────────────────
/// OptionScreen — default landing after loading.
/// Two big tap targets: AURA Notebook  |  Class Sync.
// ─────────────────────────────────────────────────────────────────────────────
class OptionScreen extends StatelessWidget {
  const OptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ────────────────────────────────────────────────────
              const Text(
                'AURA',
                style: TextStyle(
                  color:         Colors.white,
                  fontSize:      40,
                  fontWeight:    FontWeight.w900,
                  letterSpacing: 4,
                  height:        1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your space',
                style: TextStyle(
                  color:         Colors.white.withOpacity(0.45),
                  fontSize:      14,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 40),

              // ── Cards ─────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  children: [

                    // Card 1 — AURA Notebook (home)
                    Expanded(
                      child: _DestCard(
                        heroTag:    'card_aura',
                        assetPath:  'Assets/images/AURA_load.png',
                        title:      'AURA NOTEBOOK',
                        subtitle:   'Your personal AI companion',
                        accentColor: const Color(0xFFFF3CAC),
                        onTap: () => Navigator.of(context).push( // <-- CHANGED HERE
                          _fade(const home()),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card 2 — Class Sync
                    Expanded(
                      child: _DestCard(
                        heroTag:    'card_class',
                        assetPath:  'Assets/images/class_AURA.png',
                        title:      'CLASS SYNC',
                        subtitle:   'The Modern Teacher\'s Hub',
                        accentColor: const Color(0xFF00B0FF),
                        onTap: () => Navigator.of(context).push( // <-- CHANGED HERE
                          _fade(const ClassScreen()),
                        ),
                      ),
                    ),

                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  /// A smooth fade page transition.
  static PageRoute<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder:        (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

// ── Destination card ──────────────────────────────────────────────────────────
class _DestCard extends StatefulWidget {
  final String   heroTag;
  final String   assetPath;
  final String   title;
  final String   subtitle;
  final Color    accentColor;
  final VoidCallback onTap;

  const _DestCard({
    required this.heroTag,
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_DestCard> createState() => _DestCardState();
}

class _DestCardState extends State<_DestCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Hero(
          tag: widget.heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [

                // Background image
                Image.asset(
                  widget.assetPath,
                  fit:       BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),

                // Dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topCenter,
                      end:    Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.72),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),

                // Accent border
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.55),
                      width: 1.5,
                    ),
                  ),
                ),

                // Text labels
                Positioned(
                  left:   20,
                  right:  20,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize:       MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color:         Colors.white,
                          fontSize:      20,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: 1.6,
                          shadows: [
                            Shadow(
                              color:      Colors.black.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color:    Colors.white.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow hint
                Positioned(
                  right:  18,
                  bottom: 20,
                  child: Container(
                    padding:     const EdgeInsets.all(8),
                    decoration:  BoxDecoration(
                      color:       widget.accentColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size:  16,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}