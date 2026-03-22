import 'package:flutter/material.dart';
import '../widgets/widget_link.dart';

class home extends StatefulWidget{

  const home({super.key});
  @override
  State<home> createState() => _Homesy();
}

class _Homesy extends State<home>{

  @override
  Widget build(BuildContext context){
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(

      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
      return Container(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color.from(alpha: 1.0, red: 0.6, green: 0.13, blue: 0.4), // Sober border color
          width: 5.0,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.from(alpha: 1.0, red: 1.0, green: 0.98, blue: 0.94), // Pearl/Cream
              Color.from(alpha: 1.0, red: 0.98, green: 0.92, blue: 0.84), // Soft Sand
            ],
          ),
          // Adding a subtle shadow creates the 'glow' effect against the background
          boxShadow: [
            BoxShadow(
              color: Color.from(alpha: 0.2, red: 0.8, green: 0.7, blue: 0.6),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
                image_wid(
                boxColor: Colors.cyan,
                textIn: 'AURA NOTEBOOK',
                imagePath: 'Assets/images/balloon2.png',
                boxHeight: screenHeight * 0.33,boxWidth: constraints.maxWidth,
        
                ),
        
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: PixelCube(boxColor: Colors.indigoAccent,
                textIn: 'Hello Welcome To Your Notebook!',
                boxHeight: 200, boxWidth: double.infinity, textLeft: 100,),
            ),
          ],
        ),
      );
        })
    );
  }
}