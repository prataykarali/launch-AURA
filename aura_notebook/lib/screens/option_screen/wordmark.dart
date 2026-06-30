part of 'option_screen.dart';

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
