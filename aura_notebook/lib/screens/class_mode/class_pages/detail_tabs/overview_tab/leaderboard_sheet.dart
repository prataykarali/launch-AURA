import 'package:flutter/material.dart';
import '../../class_data.dart';
import '../leaderboard_tab.dart';

class LeaderboardSheet extends StatelessWidget {
  final ClassData data;
  final VoidCallback onClose;

  const LeaderboardSheet({
    super.key,
    required this.data,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.85,
    decoration: const BoxDecoration(
      color: Color(0xFF0D0D18),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(
        top:   BorderSide(color: Color(0x335C6BC0)),
        left:  BorderSide(color: Color(0x225C6BC0)),
        right: BorderSide(color: Color(0x225C6BC0)),
      ),
    ),
    child: Column(children: [
      // Handle + header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(children: [
          Center(child: Container(
            width: 38, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
          )),
          Row(children: [
            Icon(Icons.leaderboard_rounded,
                color: data.accent, size: 20),
            const SizedBox(width: 10),
            const Text('Class Leaderboard',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.35), size: 20)),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
      // Leaderboard content fills the rest
      Expanded(child: LeaderboardTab(data: data)),
    ]),
  );
}
