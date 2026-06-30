import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import '../screens/loading_screen.dart';

class MainWindow extends StatelessWidget {
  final WindowController controller;
  const MainWindow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const LoadingScreen(),
    );
  }
}