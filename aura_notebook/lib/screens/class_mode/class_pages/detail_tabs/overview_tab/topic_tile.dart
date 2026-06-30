import 'package:flutter/material.dart';
import 'topic_model.dart';

class TopicTile extends StatelessWidget {
  final Topic topic;
  final int index;
  final Color accent, color;
  final VoidCallback onToggle, onDelete;

  const TopicTile({
    super.key,
    required this.topic,
    required this.index,
    required this.accent,
    required this.color,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: topic.done ? color.withOpacity(0.12) : const Color(0xFF161625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: topic.done
            ? accent.withOpacity(0.35) : Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  topic.done ? accent : Colors.transparent,
            border: Border.all(
                color: topic.done ? accent : Colors.white30, width: 2),
          ),
          child: topic.done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : Center(child: Text('$index', style: TextStyle(
                  color: Colors.white24, fontSize: 10,
                  fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(topic.title,
            style: TextStyle(
              color: topic.done
                  ? Colors.white.withOpacity(0.45) : Colors.white,
              fontSize: 13, fontWeight: FontWeight.w500,
              decoration: topic.done ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white30,
            ))),
        if (topic.done) ...[
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('+25 XP', style: TextStyle(color: accent,
                  fontSize: 9, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
        ],
        GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 15,
                color: Colors.white.withOpacity(0.18))),
      ]),
    ),
  );
}
