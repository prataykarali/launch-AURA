  import 'package:flutter/material.dart';
  import '../widgets/widget_link.dart';

  class home extends StatelessWidget {
    const home({super.key});

    @override
    Widget build(BuildContext context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth  = MediaQuery.of(context).size.width;

      return Scaffold(
        // resizeToAvoidBottomInset keeps layout stable when keyboard opens
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
              image_wid(
                boxColor: Colors.cyan,
                textIn: 'AURA NOTEBOOK',
                imagePath: 'Assets/images/balloon2.png',
                boxHeight: screenHeight * 0.28,
                boxWidth: screenWidth,
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