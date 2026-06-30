part of 'class_screen.dart';

class _ClassFloatingButtons extends StatelessWidget {
  final VoidCallback onAiTap;
  final VoidCallback onAddTap;
  final Animation<double> pulseAnim;

  const _ClassFloatingButtons({
    required this.onAiTap,
    required this.onAddTap,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 0,
          bottom: 74,
          child: ScaleTransition(
            scale: pulseAnim,
            child: GestureDetector(
              onTap: onAiTap,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _classPrimary.withOpacity(0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_classPrimary, _classTeal],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'Assets/images/circle_detect_AURA.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: FloatingActionButton.extended(
            heroTag: 'newclass',
            onPressed: onAddTap,
            backgroundColor: _classPrimary,
            foregroundColor: Colors.white,
            elevation: 8,
            icon: const Icon(Icons.add_rounded, weight: 800),
            label: const Text(
              'NEW CLASS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
