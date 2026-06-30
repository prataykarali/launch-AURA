part of 'smart_briefing_card.dart';

extension _SmartBriefingCardUI on _SmartBriefingCardState {
  Widget _buildBody() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: ValueListenableBuilder<String>(
      valueListenable: _streamText,
      builder: (_, txt, __) {
        if (txt.isEmpty && _loading) return _buildLoadingState();
        if (_hasError && txt.isEmpty)  return _buildErrorState();

        final lines = txt
            .replaceAll('▍', '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: txt.isEmpty ? 0.0 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                line + (line == lines.last && _loading ? '▍' : ''),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.5,
                    letterSpacing: 0.2),
              ),
            )).toList(),
          ),
        );
      },
    ),
  );

  Widget _buildLoadingState() => Row(children: [
    const SizedBox(
      width: 14, height: 14,
      child: CircularProgressIndicator(
          strokeWidth: 1.5, color: Color(0xFF7C4DFF)),
    ),
    const SizedBox(width: 12),
    Text('AURA is composing...',
        style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12, fontStyle: FontStyle.italic)),
  ]);

  Widget _buildErrorState() => Row(
    children: [
      Icon(Icons.error_outline_rounded,
          size: 16, color: Colors.orange.withOpacity(0.6)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Could not generate briefing. Tap ↻ to retry.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.35), fontSize: 12),
        ),
      ),
    ],
  );
}
