part of '../main.dart';

// ── STEP LIST ─────────────────────────────────────────────────────────────────
class _StepList extends StatelessWidget {
  final _Step currentStep;
  const _StepList({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _Step.values.map((step) {
        final isDone = step.index < currentStep.index;
        final isActive = step == currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: isDone
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF991A66),
                        size: 18,
                      )
                    : isActive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF991A66),
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.indigo.shade100,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isDone
                      ? const Color(0xFF991A66)
                      : isActive
                      ? Colors.indigo.shade400
                      : Colors.indigo.shade100,
                ),
                child: Text(step.label),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
