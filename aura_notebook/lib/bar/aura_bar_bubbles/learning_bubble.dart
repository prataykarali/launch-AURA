// ignore_for_file: use_key_in_widget_constructors
import 'package:flutter/material.dart';

class LearningBubble extends StatefulWidget {
  final String message;
  const LearningBubble({required this.message});

  @override
  State<LearningBubble> createState() => _LearningBubbleState();
}

class _LearningBubbleState extends State<LearningBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0E0628).withOpacity(0.94),
                const Color(0xFF1a0a3d).withOpacity(0.94),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF818CF8).withOpacity(0.3),
                const Color(0xFFA78BFA).withOpacity(0.7),
                _shimmerAnim.value,
              )!,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF818CF8,
                ).withOpacity(0.2 + 0.2 * _shimmerAnim.value),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFF818CF8),
                    const Color(0xFFA78BFA),
                    _shimmerAnim.value,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF818CF8).withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [
                      Color.lerp(
                        const Color(0xFF818CF8),
                        const Color(0xFFD5A3FF),
                        _shimmerAnim.value,
                      )!,
                      const Color(0xFFA78BFA),
                    ],
                  ).createShader(b),
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
