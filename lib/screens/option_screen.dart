import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_mode/home_screen.dart';
import 'class_mode/class_screen.dart';
import 'info_page.dart';

class OptionScreen extends StatefulWidget {
  const OptionScreen({super.key});

  @override
  State<OptionScreen> createState() => _OptionScreenState();
}

class _OptionScreenState extends State<OptionScreen> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  late final AnimationController _orbCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _orbCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _openWorldSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.80,
        child: _WorldSheet(
          onAura: () {
            Navigator.pop(context);
            Navigator.of(context).pushReplacement(_fade(const home()));
          },
          onClass: () {
            Navigator.pop(context);
            Navigator.of(context).push(_fade(const ClassScreen()));
          },
          onInfo: () {
            Navigator.pop(context);
            Navigator.of(context).push(_fade(const InfoPage()));
          },
        ),
      ),
    );
  }

  static Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'Assets/images/option_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackBg(ctrl: _shimmerCtrl),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.82),
                    ],
                    stops: const [0.2, 0.65, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) {
                final t = _orbCtrl.value;
                return Positioned(
                  right: -60,
                  top: size.height * 0.12 + math.sin(t * math.pi) * 20,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF7C4DFF).withOpacity(0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.08),
                      _Wordmark(shimmer: _shimmerCtrl),
                      const Spacer(),
                      _CentreTagline(orb: _orbCtrl),
                      const Spacer(),
                      _SelectButton(onTap: _openWorldSheet),
                      const SizedBox(height: 48),
                    ],
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

class _Wordmark extends StatelessWidget {
  final AnimationController shimmer;
  const _Wordmark({required this.shimmer});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          final t = shimmer.value;
          return ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(t * 3 - 2, 0),
              end: Alignment(t * 3, 0),
              colors: const [Colors.white, Color(0xFFE0BBFF), Colors.white, Colors.white],
              stops: const [0.0, 0.45, 0.55, 1.0],
            ).createShader(rect),
            child: const Text(
              'AURA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
                height: 1,
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 6),
    ],
  );
}

class _CentreTagline extends StatelessWidget {
  final AnimationController orb;
  const _CentreTagline({required this.orb});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 40, height: 1, color: Colors.white.withOpacity(0.25)),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: orb,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(const Color(0xFFFF3CAC), const Color(0xFF7C4DFF), orb.value),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF3CAC).withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 40, height: 1, color: Colors.white.withOpacity(0.25)),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        'Your intelligent companion',
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 20,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'for learning and teaching',
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 16,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _SelectButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SelectButton({required this.onTap});

  @override
  State<_SelectButton> createState() => _SelectButtonState();
}

class _SelectButtonState extends State<_SelectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ac.forward(),
    onTapUp: (_) {
      _ac.reverse();
      widget.onTap();
    },
    onTapCancel: () => _ac.reverse(),
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3CAC), Color(0xFF7C4DFF), Color(0xFF00B0FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Select Your World',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FallbackBg extends StatelessWidget {
  final AnimationController ctrl;
  const _FallbackBg({required this.ctrl});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, __) {
      final t = ctrl.value;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(const Color(0xFF0D0D18), const Color(0xFF1A0A2E), t)!,
              const Color(0xFF0D0D18),
              Color.lerp(const Color(0xFF0A1A2E), const Color(0xFF0D0D18), t)!,
            ],
          ),
        ),
      );
    },
  );
}

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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0F0F1A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: const Color(0x22FFFFFF)), // ✅ uniform border color
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
  );
}

class _WorldCard extends StatefulWidget {
  final String assetPath, title, subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _WorldCard({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_WorldCard> createState() => _WorldCardState();
}

class _WorldCardState extends State<_WorldCard> with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  widget.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: widget.accent.withOpacity(0.15)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black.withOpacity(0.72), Colors.black.withOpacity(0.2)],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: widget.accent.withOpacity(0.45), width: 1.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 16,
                  right: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.withOpacity(0.9),
                      boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.4), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}