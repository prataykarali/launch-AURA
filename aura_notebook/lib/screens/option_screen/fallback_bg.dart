part of 'option_screen.dart';

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
