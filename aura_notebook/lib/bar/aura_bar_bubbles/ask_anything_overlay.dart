// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class AskAnythingOverlay extends StatelessWidget {
  final VoidCallback? onTap;
  const AskAnythingOverlay({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0628).withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFF9CEE),
              size: 14,
            ),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF9CEE), Color(0xFF90F0DF)],
              ).createShader(bounds),
              child: const Text(
                "Ask AURA Anything",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
