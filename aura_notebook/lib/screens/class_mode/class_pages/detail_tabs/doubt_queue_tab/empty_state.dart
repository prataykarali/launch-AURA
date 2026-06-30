import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final Color accent;

  const EmptyState({super.key, required this.accent});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded,
                size: 52, color: accent.withOpacity(0.3)),
            const SizedBox(height: 14),
            const Text(
              'No doubts yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Post a question and AURA will\nanswer it instantly!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
      );
}
