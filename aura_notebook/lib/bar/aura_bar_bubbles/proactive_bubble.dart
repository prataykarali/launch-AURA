// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class ProactiveBubble extends StatelessWidget {
  final String message;
  const ProactiveBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0628).withOpacity(0.92),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (b) => const LinearGradient(
          colors: [Color(0xFFFF9CEE), Color(0xFFD5A3FF), Color(0xFF90F0DF)],
        ).createShader(b),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
