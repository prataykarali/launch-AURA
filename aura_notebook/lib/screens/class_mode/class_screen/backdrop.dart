part of 'class_screen.dart';

class _ClassroomBackdrop extends StatelessWidget {
  const _ClassroomBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _classPrimary.withOpacity(0.10),
            Colors.transparent,
            _classTeal.withOpacity(0.12),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              _classGold.withOpacity(0.08),
              Colors.transparent,
              Colors.black.withOpacity(0.12),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}
