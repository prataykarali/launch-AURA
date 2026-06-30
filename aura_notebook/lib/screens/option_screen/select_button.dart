part of 'option_screen.dart';

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
