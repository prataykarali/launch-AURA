import 'package:flutter/material.dart';
import 'option_screen.dart';

class ChildLoadingScreen extends StatefulWidget {
  const ChildLoadingScreen({super.key});
  @override
  State<ChildLoadingScreen> createState() => _ChildLoadingScreenState();
}

class _ChildLoadingScreenState extends State<ChildLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Straight to UI — engine is in bar process
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OptionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      ),
    );
  }
}