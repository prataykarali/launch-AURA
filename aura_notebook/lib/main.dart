import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/screens.dart';
import 'package:aura_notebook/src/rust/frb_generated.dart';
import 'package:aura_notebook/src/rust/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA NOTEBOOK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const _ModelLoader(),
    );
  }
}

class _ModelLoader extends StatefulWidget {
  const _ModelLoader();
  @override
  State<_ModelLoader> createState() => _ModelLoaderState();
}

class _ModelLoaderState extends State<_ModelLoader> {
  String _status = 'waking up AURA…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = 'finding paths…');

    try {
      final mPath = await PathManager.getModelPath();
      final tPath = await PathManager.getTokenizerPath();

      setState(() => _status = 'loading model…');

      final ok = await auraInit(modelPath: mPath, tokenizerPath: tPath);

      if (!ok) {
        setState(() => _status = '❌ Engine failed to start!');
        return;
      }

      // ... navigate to home
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFAF0), Color(0xFFFAEBD7)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('Assets/images/balloon2.png', height: 130),
              const SizedBox(height: 24),
              const Text('AURA NOTEBOOK',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      letterSpacing: 2, color: Color(0xFF991A66))),
              const SizedBox(height: 20),
              const SizedBox(width: 28, height: 28,
                  child: CircularProgressIndicator(
                      color: Color(0xFF991A66), strokeWidth: 2)),
              const SizedBox(height: 12),
              Text(_status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.indigo.shade200,
                      fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}