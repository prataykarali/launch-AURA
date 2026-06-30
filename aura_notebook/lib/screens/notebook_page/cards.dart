import 'package:flutter/material.dart';
import 'chat_bubble.dart';
import 'date_helpers.dart';
import 'models.dart';

class TurnCard extends StatelessWidget {
  final Turn turn;
  final int index;
  const TurnCard({super.key, required this.turn, required this.index});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.indigo.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        title: Text(
          turn.user,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          '${formatShort(turn.ts)}, ${formatTime(turn.ts)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
        children: [
          ChatBubble(text: turn.user, isUser: true),
          const SizedBox(height: 8),
          ChatBubble(text: turn.aura, isUser: false),
          const SizedBox(height: 8),
          Text(
            formatFull(turn.ts),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    ),
  );
}

class SummaryCard extends StatelessWidget {
  final Summary summary;
  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.topicLabel.isEmpty
                      ? 'General Topic'
                      : summary.topicLabel,
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${formatShort(summary.createdAt)}, ${formatTime(summary.createdAt)}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class FactCard extends StatelessWidget {
  final Fact fact;
  const FactCard({super.key, required this.fact});

  String _formatKey(String key) {
    return key
        .split('_')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              color: Colors.teal.shade700,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatKey(fact.key),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fact.value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatShort(fact.updatedAt),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
