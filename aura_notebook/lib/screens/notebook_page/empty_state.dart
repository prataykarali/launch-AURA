import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.book_outlined, color: Colors.indigo.shade100, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.indigo.shade300,
            fontSize: 14,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}
