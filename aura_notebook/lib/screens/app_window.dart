import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../bar/bar_multi_window_service.dart';
import 'loading_screen.dart';
import 'option_screen.dart';

class AppWindowApp extends StatefulWidget {
  const AppWindowApp({super.key});

  @override
  State<AppWindowApp> createState() => _AppWindowAppState();
}

class _AppWindowAppState extends State<AppWindowApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const _AppWindowShell(),
    );
  }
}

class _AppWindowShell extends StatefulWidget {
  const _AppWindowShell();
  @override
  State<_AppWindowShell> createState() => _AppWindowShellState();
}

class _AppWindowShellState extends State<_AppWindowShell> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _loaded ? 1 : 0,
        children: [
          LoadingScreen(onDone: () {
            if (mounted) setState(() => _loaded = true);
          }),
          const OptionScreen(),
        ],
      ),
    );
  }
}