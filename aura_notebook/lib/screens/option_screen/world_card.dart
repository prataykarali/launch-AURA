part of 'option_screen.dart';

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
