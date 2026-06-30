part of 'option_screen.dart';

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
