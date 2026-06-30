part of 'ai_quiz_tab.dart';

// ── Generating screen ─────────────────────────────────────────────────────
extension _AiQuizTabStateGenerating on _AiQuizTabState {
  Widget _buildGenerating(ClassData d) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: d.accent, strokeWidth: 2),
        const SizedBox(height: 20),
        Text('AURA is writing your quiz…',
            style: TextStyle(color: Colors.white.withOpacity(0.6),
                fontSize: 14, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        // Live stream preview
        Container(
          height: 120,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161625),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: d.accent.withOpacity(0.2)),
          ),
          child: SingleChildScrollView(
            child: ValueListenableBuilder<String>(
              valueListenable: _streamNotifier,
              builder: (_, txt, __) => Text(txt,
                  style: TextStyle(color: Colors.white.withOpacity(0.4),
                      fontSize: 11, height: 1.4)),
            ),
          ),
        ),
      ]),
    ),
  );
}
