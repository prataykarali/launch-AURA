import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/utils/path_manager.dart';
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

// ── LOADING STEP MODEL ───────────────────────────────────────────────────────
enum _Step { wake, paths, model, ready }

extension _StepLabel on _Step {
  String get label {
    switch (this) {
      case _Step.wake:  return 'Waking up AURA';
      case _Step.paths: return 'Finding model files';
      case _Step.model: return 'Loading model weights';
      case _Step.ready: return 'Ready!';
    }
  }
}

// ── MODEL LOADER SCREEN ──────────────────────────────────────────────────────
class _ModelLoader extends StatefulWidget {
  const _ModelLoader();
  @override
  State<_ModelLoader> createState() => _ModelLoaderState();
}

class _ModelLoaderState extends State<_ModelLoader>
    with SingleTickerProviderStateMixin {

  // Balloon float animation
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  _Step _currentStep = _Step.wake;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    // Gentle float: 8px up and down, 2-second cycle
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _load();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── LOADING LOGIC ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    _setStep(_Step.wake);
    // One frame yield so the UI paints before we do any work
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      _setStep(_Step.paths);
      await Future.delayed(const Duration(milliseconds: 32));

      final mPath = await PathManager.getModelPath();
      final tPath = await PathManager.getTokenizerPath();

      if (!File(mPath).existsSync()) {
        _setError('Model file not found:\n$mPath');
        return;
      }
      if (!File(tPath).existsSync()) {
        _setError('Tokenizer not found:\n$tPath');
        return;
      }

      _setStep(_Step.model);

      // Yield one more frame so the "Loading model weights" step paints,
      // then call auraInit. The Rust call will block this isolate, but the
      // spinner and balloon float are driven by the Ticker on the raster
      // thread and keep animating even when Dart is blocked on FFI.
      //
      // If your FRB version supports Isolate.run, swap this for:
      //   final ok = await Isolate.run(() => auraInit(...));
      await Future.delayed(const Duration(milliseconds: 16));
      final String modelPath = mPath;
      final String tokenizerPath = tPath;

      final ok = await Isolate.run(() async {
        // 1. Initialize the bridge INSIDE the background isolate
        await RustLib.init();

        // 2. Now call your engine initialization
        return auraInit(
            modelPath: modelPath,
            tokenizerPath: tokenizerPath
        );
      });
      if (!ok) {
        _setError('Engine failed to start. Check your model file.');
        return;
      }

      _setStep(_Step.ready);
      // Brief pause so the user sees the "Ready!" checkmark
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const home()),
      );
    } catch (e, st) {
      _setError('Unexpected error:\n$e');
      debugPrint('$e\n$st');
    }
  }

  void _setStep(_Step step) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _errorMsg = null;
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() => _errorMsg = msg);
    HapticFeedback.heavyImpact();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
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
              // ── Floating balloon ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: child,
                ),
                child: Image.asset(
                  'Assets/images/balloon2.png',
                  height: 130,
                ),
              ),

              const SizedBox(height: 28),

              // ── App title ─────────────────────────────────────────────────
              const Text(
                'AURA NOTEBOOK',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF991A66),
                ),
              ),

              const SizedBox(height: 32),

              // ── Progress steps ────────────────────────────────────────────
              if (_errorMsg == null)
                _StepList(currentStep: _currentStep),

              // ── Error state ───────────────────────────────────────────────
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFF991A66), size: 32),
                      const SizedBox(height: 12),
                      Text(
                        _errorMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF991A66),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── STEP LIST WIDGET ─────────────────────────────────────────────────────────
class _StepList extends StatelessWidget {
  final _Step currentStep;
  const _StepList({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _Step.values.map((step) {
        final isDone    = step.index < currentStep.index;
        final isActive  = step == currentStep;
        final isPending = step.index > currentStep.index;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon / spinner
              SizedBox(
                width: 20,
                height: 20,
                child: isDone
                    ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF991A66), size: 18)
                    : isActive
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Color(0xFF991A66),
                    strokeWidth: 2,
                  ),
                )
                    : Icon(Icons.radio_button_unchecked,
                    color: Colors.indigo.shade100, size: 18),
              ),

              const SizedBox(width: 10),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isDone
                      ? const Color(0xFF991A66)
                      : isActive
                      ? Colors.indigo.shade400
                      : Colors.indigo.shade100,
                ),
                child: Text(step.label),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}