part of 'students_tab.dart';

// ── Catch-Up ──────────────────────────────────────────────────────────────────
class _CatchUpView extends StatelessWidget {
  final List<StudentModel> students; final Color accent;
  const _CatchUpView({required this.students, required this.accent});
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.check_circle_outline_rounded,
        size: 48, color: Colors.greenAccent.withOpacity(0.5)),
    const SizedBox(height: 12),
    Text('All caught up!', style: TextStyle(
        color: Colors.white.withOpacity(0.4), fontSize: 15,
        fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('No students need catch-up materials.', style: TextStyle(
        color: Colors.white.withOpacity(0.25), fontSize: 12)),
  ]));
}
