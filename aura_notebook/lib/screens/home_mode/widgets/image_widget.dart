import 'package:flutter/material.dart';

class image_wid extends StatefulWidget{
  final Color boxColor;
  final String textIn;
  final double? boxWidth;
  final double? boxHeight;
  final double textTop;
  final double textLeft;
  final String imagePath;
  final double imageYAlign;
  const image_wid({
    super.key,
    required this.boxColor,
    required this.textIn,
    this.boxHeight,
    this.boxWidth,
    this.textLeft =16.0,
    this.textTop= 16.0,
    required this.imagePath,
    this.imageYAlign = 0.0,
  });
  @override
  State<image_wid> createState() =>_imag();
}
class _imag extends State<image_wid>{
  @override
  Widget build(BuildContext context){
    return
      InkWell(
        child: Container(
          width: widget.boxWidth,
          height: widget.boxHeight,
          color: widget.boxColor,
          child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(widget.imagePath
                    ,fit: BoxFit.cover,
                    alignment: Alignment(0.0, widget.imageYAlign),
                  ),

                ),
                Positioned(
                  top:widget.textTop,
                  left:widget.textLeft,
                  child: Text(
                      widget.textIn,
                      style: const TextStyle(color: Colors.white, fontSize: 20)),
                ),

              ]),

        ),
      );
  }
}