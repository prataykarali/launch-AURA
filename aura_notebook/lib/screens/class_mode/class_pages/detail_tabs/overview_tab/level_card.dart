import 'package:flutter/material.dart';
import '../../class_data.dart';

class LevelCard extends StatelessWidget {
  final int xp, level, xpIn, xpNeeded;
  final Color accent;
  final Animation<double> anim;

  const LevelCard({
    super.key,
    required this.xp,
    required this.level,
    required this.xpIn,
    required this.xpNeeded,
    required this.accent,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final pct   = xpNeeded == 0 ? 0.0 : xpIn / xpNeeded;
    final title = XpSystem.levelTitle(level);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: [const Color(0xFF1A1A2E), accent.withOpacity(0.1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              accent.withOpacity(0.9), accent.withOpacity(0.25)]),
            boxShadow: [BoxShadow(
                color: accent.withOpacity(0.35), blurRadius: 16)],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Lv', style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9, fontWeight: FontWeight.w600)),
                Text('$level', style: const TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
              ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Class Level $level',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(title, style: TextStyle(color: accent.withOpacity(0.7),
                              fontSize: 10, fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                        ]),
                    Text('$xpIn / $xpNeeded XP',
                        style: TextStyle(color: accent, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
              const SizedBox(height: 8),
              AnimatedBuilder(animation: anim, builder: (_, __) =>
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                          value: pct * anim.value,
                          backgroundColor: Colors.white.withOpacity(0.07),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 7))),
              const SizedBox(height: 5),
              xp == 0
                  ? Text('Complete topics to earn XP!',
                      style: TextStyle(color: Colors.white.withOpacity(0.3),
                          fontSize: 10))
                  : Text('${xpNeeded - xpIn} XP to Lv ${level + 1} · ${XpSystem.levelTitle(level + 1)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.35),
                          fontSize: 10)),
            ])),
      ]),
    );
  }
}
