import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/utils/responsive.dart';
import '../home_mode/home_screen.dart';
import '../class_mode/class_screen.dart';
import '../info_page.dart';

part 'wordmark.dart';
part 'centre_tagline.dart';
part 'select_button.dart';
part 'fallback_bg.dart';
part 'world_sheet.dart';
part 'world_card.dart';

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
                fit: R.isDesktop ? BoxFit.fitWidth : BoxFit.cover,
                alignment: Alignment.topCenter,
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
              child: R.maxWidth(
                FadeTransition(
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
                max: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
