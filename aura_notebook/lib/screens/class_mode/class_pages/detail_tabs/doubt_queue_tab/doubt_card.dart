import 'package:flutter/material.dart';
import 'doubt_model.dart';

class DoubtCard extends StatelessWidget {
  final Doubt doubt;
  final Color accent, color;
  final VoidCallback onEscalate, onHelpful;

  const DoubtCard({
    super.key,
    required this.doubt,
    required this.accent,
    required this.color,
    required this.onEscalate,
    required this.onHelpful,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: doubt.escalated
                ? Colors.orange.withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.help_rounded,
                        color: accent, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doubt.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _timeAgo(doubt.timestamp),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.28),
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (doubt.escalated) _badge('Escalated', Colors.orange),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withOpacity(0.05)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF40C4FF)],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: doubt.streamText,
                      builder: (_, txt, __) => txt.isEmpty
                          ? _loadingState()
                          : Text(
                              txt,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (doubt.isAnswered && !doubt.escalated && !doubt.markedHelpful)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Text(
                      'Was this helpful?',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11),
                    ),
                    const Spacer(),
                    ActionBtn(
                        label: '👍 Yes',
                        color: Colors.greenAccent,
                        onTap: onHelpful),
                    const SizedBox(width: 8),
                    ActionBtn(
                        label: '📢 Escalate',
                        color: Colors.orange,
                        onTap: onEscalate),
                  ],
                ),
              ),
            if (doubt.markedHelpful) _helpfulFooter(),
          ],
        ),
      );

  Widget _badge(String text, Color col) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: col.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: col, fontSize: 9, fontWeight: FontWeight.w700)),
      );

  Widget _loadingState() => Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: const Color(0xFF7C4DFF).withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AURA is answering…',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      );

  Widget _helpfulFooter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 13, color: Colors.greenAccent),
            const SizedBox(width: 5),
            Text(
              'Marked helpful',
              style: TextStyle(
                  color: Colors.greenAccent.withOpacity(0.5),
                  fontSize: 11),
            ),
          ],
        ),
      );

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
