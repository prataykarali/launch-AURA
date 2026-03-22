import 'package:flutter/material.dart';

class PixelCube extends StatefulWidget{
  final Color boxColor;
  final String textIn;
  final double? boxWidth;
  final double? boxHeight;
  final double textTop;
  final double textLeft;
  const PixelCube({
    super.key,
    required this.boxColor,
    required this.textIn,
    this.boxHeight,
    this.boxWidth,
    this.textLeft =16.0,
    this.textTop= 16.0,
  });
  @override
  State<PixelCube> createState() =>_BluePix();
}
class _BluePix extends State<PixelCube> {
  bool _isEditing = false;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.textIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = true;
    });
    // Ensures the keyboard pops up immediately
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isEditing ? null : _toggleEdit, // Disable tap if already editing
        child: Ink(
          width: widget.boxWidth ?? double.infinity,
          height: widget.boxHeight ?? 100,
          decoration: BoxDecoration(
            color: widget.boxColor,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: _isEditing ? _buildInput() : _buildDisplay(),
        ),
      ),
    );
  }

  // The "Sober" Display Mode
  Widget _buildDisplay() {
    return Stack(
      children: [
        Positioned(
          top: widget.textTop,
          left: widget.textLeft,
          child: Text(
            widget.textIn,
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ],
    );
  }

  // The "Input" Mode
  Widget _buildInput() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(left: widget.textLeft, right: 16),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            border: InputBorder.none, // Keeps the sober look
            hintText: "Enter text...",
            hintStyle: TextStyle(color: Colors.white54),
          ),
          onSubmitted: (value) {
            setState(() {
              _isEditing = false;
            });
            // You can add a callback here to save the text
          },
        ),
      ),
    );
  }
}