// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class WarningBubble extends StatelessWidget {
  final String message;
  const WarningBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final displayMessage = message.isNotEmpty
        ? message
        : 'AURA paused extra work. Close something heavy, then try again.';
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF24110F).withOpacity(0.94),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.28),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFFD166),
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              displayMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
