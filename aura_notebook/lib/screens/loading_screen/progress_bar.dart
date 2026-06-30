part of 'main.dart';

class _ProgressBar extends StatelessWidget {
  final double progress;
  final AnimationController shimmerCtrl;
  const _ProgressBar({required this.progress, required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fillWidth = maxWidth * progress.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 24,
              width: maxWidth,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 24,
                  width: fillWidth,
                  child: AnimatedBuilder(
                    animation: shimmerCtrl,
                    builder: (_, __) => Stack(
                      children: [
                        Positioned(
                          left: -(shimmerCtrl.value * 60),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: maxWidth + 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: FractionalOffset(0.0, 0.0),
                                end: FractionalOffset(0.12, 1.0),
                                stops: [0.0, 0.5, 0.5, 1.0],
                                colors: [
                                  Color(0xFF4CAF50),
                                  Color(0xFF4CAF50),
                                  Colors.white,
                                  Colors.white,
                                ],
                                tileMode: TileMode.repeated,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
