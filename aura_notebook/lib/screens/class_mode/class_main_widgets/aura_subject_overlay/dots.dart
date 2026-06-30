part of 'package:aura_notebook/screens/class_mode/class_main_widgets/aura_subject_overlay.dart';

// ── Dots ──────────────────────────────────────────────────────────────────────
class _Dots extends StatefulWidget {
  @override
  State<_Dots> createState() => _DotsState();
}
class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  @override
  void initState() { super.initState();
  _ac = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 900))..repeat();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final p = ((_ac.value * 3) - i).clamp(0.0, 1.0);
        final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.25, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 5, height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF).withOpacity(o),
            shape: BoxShape.circle,
          ),
        );
      }),
    ),
  );
}
