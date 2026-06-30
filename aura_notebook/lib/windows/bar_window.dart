import 'package:flutter/material.dart';
import '../screens/loading_screen.dart';
import '../screens/option_screen.dart';

// No window_manager import — not available in child process

class MainWindowApp extends StatelessWidget {
  final String windowId;
  const MainWindowApp({super.key, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _MainWindowShell(windowId: windowId),
    );
  }
}

class _MainWindowShell extends StatefulWidget {
  final String windowId;
  const _MainWindowShell({super.key, required this.windowId});

  @override
  State<_MainWindowShell> createState() => _MainWindowShellState();
}

class _MainWindowShellState extends State<_MainWindowShell> {
  // No WindowListener — window_manager not available in child
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps both widgets alive — never destroys/replaces
    // the root widget tree, avoiding the desktop_multi_window RemoveWindow bug
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _loaded ? 1 : 0,
        children: [
          LoadingScreen(onDone: () {
            if (mounted) setState(() => _loaded = true);
          }),
          // OptionScreen is built immediately but hidden until loaded
          const OptionScreen(),
        ],
      ),
    );
  }
}