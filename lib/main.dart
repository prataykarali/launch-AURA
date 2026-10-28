import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/utils/path_manager.dart';
import 'screens/home_page.dart';
import 'package:aura_notebook/src/rust/frb_generated.dart';
import 'package:aura_notebook/src/rust/api.dart';

part 'main/model_loader.dart';
part 'main/step_list.dart';

const _kModelUrl =
    'https://huggingface.co/LiquidAI/LFM2.5-230M-GGUF/resolve/main/LFM2.5-230M-Q4_K_M.gguf';
const _kTokenizerUrl =
    'https://huggingface.co/LiquidAI/LFM2.5-230M/resolve/main/tokenizer.json';
const _kModelFilename = 'LFM2.5-230M-Q4_K_M.gguf';
const _kTokenizerFilename = 'tokenizer.json';

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

enum _Step { wake, check, download, engine, ready }

extension _StepLabel on _Step {
  String get label {
    switch (this) {
      case _Step.wake:
        return 'Waking up AURA';
      case _Step.check:
        return 'Checking model files';
      case _Step.download:
        return 'Downloading model...';
      case _Step.engine:
        return 'Loading AURA...';
      case _Step.ready:
        return 'Ready!';
    }
  }
}
