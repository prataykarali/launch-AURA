part of 'package:aura_notebook/screens/info_page.dart';

class _FallbackBanner extends StatelessWidget {
  final AnimationController ctrl;
  const _FallbackBanner({required this.ctrl});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (context, child) => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF1A0A2E),
              const Color(0xFF0A1A3E),
              ctrl.value,
            )!,
            const Color(0xFF0D0D18),
          ],
        ),
      ),
      child: Stack(
        children: [
          for (int i = 0; i < 3; i++)
            Positioned(
              left: 50.0 + i * 120,
              top: 20.0 + math.sin(ctrl.value * math.pi * 2 + i) * 30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      [
                        const Color(0xFF7C4DFF),
                        const Color(0xFF40C4FF),
                        const Color(0xFFFF3CAC),
                      ][i].withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    ),
  );
}
