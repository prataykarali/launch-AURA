import 'package:flutter/material.dart';
import '../widgets/widget_link.dart';
import 'option_screen.dart';

class home extends StatelessWidget {
  const home({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth  = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.from(
                alpha: 1.0, red: 0.6, green: 0.13, blue: 0.4),
            width: 5.0,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.from(alpha: 1.0, red: 1.0, green: 0.98, blue: 0.94),
              Color.from(alpha: 1.0, red: 0.98, green: 0.92, blue: 0.84),
            ],
          ),
        ),
        child: Column(
          children: [
            // ── Stack to overlay back button on top of image_wid ─────────
            Stack(
              children: [
                image_wid(
                  boxColor: Colors.cyan,
                  textIn: 'AURA NOTEBOOK',
                  imagePath: 'Assets/images/balloon2.png',
                  boxHeight: screenHeight * 0.28,
                  boxWidth: screenWidth,
                ),
                // Back button — top-left, respects status bar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const OptionScreen(),
                        transitionDuration: const Duration(milliseconds: 300),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                      ),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.88),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Expanded(
              child: AuraChatWidget(),
            ),
          ],
        ),
      ),
    );
  }
}