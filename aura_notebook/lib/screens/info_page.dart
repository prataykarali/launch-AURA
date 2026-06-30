import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

part 'info_page/fallback_banner.dart';
part 'info_page/info_body.dart';
part 'info_page/section.dart';
part 'info_page/info_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InfoPage — AURA Credentials and Core Features
// ─────────────────────────────────────────────────────────────────────────────
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0D0D18),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF0D0D18),
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'Assets/images/info_banner.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _FallbackBanner(ctrl: _orbCtrl),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.75),
                          const Color(0xFF0D0D18),
                        ],
                        stops: const [0.0, 0.4, 0.78, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _orbCtrl,
                          builder: (context, child) => Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: SweepGradient(
                                transform: GradientRotation(
                                  _orbCtrl.value * math.pi * 2,
                                ),
                                colors: const [
                                  Color(0xFF7C4DFF),
                                  Color(0xFF40C4FF),
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C4DFF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7C4DFF,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AURA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                              ),
                            ),
                            Text(
                              'Local companion build',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: _InfoBody(orbCtrl: _orbCtrl),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
