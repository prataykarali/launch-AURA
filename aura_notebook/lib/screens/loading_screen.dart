import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/utils/path_manager.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'option_screen.dart';

// ── HuggingFace URLs ──────────────────────────────────────────────────────────
const _kModelUrl          = 'https://huggingface.co/Prataykarali/aura-lfm2/resolve/main/LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerUrl      = 'https://huggingface.co/Prataykarali/aura-lfm2/resolve/main/tokenizer.json';
const _kModelFilename     = 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerFilename = 'tokenizer.json';

const _kQuotes = [
  'AURA is always by your side! 💖',
  'When its time for adventure count on me! 🚀',
  'Heads up traveller! Lets get started! ✨',
  'Lets have some free time together... 🎮',
  'A companion whos always there to be with you! 🌟',
];

enum _Step { wake, check, download, engine, ready }

// ─────────────────────────────────────────────────────────────────────────────
/// Full-screen loading / bootstrapping widget.
// ─────────────────────────────────────────────────────────────────────────────
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {

  late final AnimationController _shimmerCtrl;
  late final AnimationController _quoteCtrl;
  late final Animation<double>   _quoteFade;

  final Random _random = Random();
  late List<String> _shuffledQuotes;

  _Step   _currentStep    = _Step.wake;
  String? _errorMsg;
  double? _downloadProgress;
  bool    _loadingLock    = false;
  int     _quoteIndex     = 0;
  double  _progressTarget = 0.02;

  static const _stepProgress = {
    _Step.wake:     0.02,
    _Step.check:    0.12,
    _Step.download: 0.48,
    _Step.engine:   0.82,
    _Step.ready:    1.00,
  };

  @override
  void initState() {
    super.initState();
    _shuffledQuotes = List.of(_kQuotes)..shuffle(_random);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _quoteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
    _quoteFade = CurvedAnimation(parent: _quoteCtrl, curve: Curves.easeIn);

    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _cycleQuote() async {
    if (_errorMsg != null) return;
    HapticFeedback.selectionClick();
    await _quoteCtrl.reverse();
    if (!mounted) return;

    setState(() {
      _quoteIndex++;
      if (_quoteIndex >= _shuffledQuotes.length) {
        _shuffledQuotes.shuffle(_random);
        _quoteIndex = 0;
      }
    });

    await _quoteCtrl.forward();
  }

  Future<void> _download(String url, String destPath) async {
    Uri uri = Uri.parse(url);
    HttpClientResponse? response;
    final client = HttpClient();
    for (int i = 0; i < 5; i++) {
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      response = await req.close();
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers.value('location');
        if (location == null) break;
        await response.drain<void>();
        uri = Uri.parse(location);
        continue;
      }
      break;
    }
    if (response == null || response.statusCode != 200) {
      client.close();
      throw Exception('HTTP ${response?.statusCode}');
    }
    final total    = response.contentLength;
    final sink     = File(destPath).openWrite();
    int   received = 0;
    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && mounted) {
        setState(() => _downloadProgress = received / total);
      }
    }
    await sink.flush();
    await sink.close();
    client.close();
  }

  Future<void> _load() async {
    if (_loadingLock) return;
    _loadingLock = true;
    _setStep(_Step.wake);
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      _setStep(_Step.check);
      await Future.delayed(const Duration(milliseconds: 32));

      final dir       = await PathManager.getModelsDir();
      final modelPath = '$dir/$_kModelFilename';
      final tokPath   = '$dir/$_kTokenizerFilename';

      final modelFile   = File(modelPath);
      final modelExists = modelFile.existsSync() &&
          modelFile.lengthSync() > 100 * 1024 * 1024;

      if (!modelExists) {
        _setStep(_Step.download);
        if (mounted) setState(() => _downloadProgress = 0.0);
        try {
          await Directory(dir).create(recursive: true);
          await _download(_kModelUrl, modelPath);
        } catch (e) {
          if (modelFile.existsSync()) modelFile.deleteSync();
          _setError('Model download failed:\n$e\n\nCheck internet connection.');
          _loadingLock = false;
          return;
        }
        if (mounted) setState(() => _downloadProgress = null);
      }

      final tokFile   = File(tokPath);
      final tokExists = tokFile.existsSync() && tokFile.lengthSync() > 1024;
      if (!tokExists) {
        if (mounted) setState(() => _downloadProgress = 0.0);
        try {
          await _download(_kTokenizerUrl, tokPath);
        } catch (e) {
          if (tokFile.existsSync()) tokFile.deleteSync();
          _setError('Tokenizer download failed:\n$e');
          _loadingLock = false;
          return;
        }
        if (mounted) setState(() => _downloadProgress = null);
      }

      _setStep(_Step.engine);
      final ok = await auraInit(modelPath: modelPath, tokenizerPath: tokPath);
      if (!ok) {
        _setError('Engine failed to start.');
        _loadingLock = false;
        return;
      }

      _setStep(_Step.ready);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OptionScreen()),
      );
    } catch (e, st) {
      _setError('Unexpected error:\n$e');
      debugPrint('$e\n$st');
      _loadingLock = false;
    }
  }

  void _setStep(_Step step) {
    if (!mounted) return;
    setState(() {
      _currentStep    = step;
      _errorMsg       = null;
      _progressTarget = _stepProgress[step] ?? 0.0;
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _errorMsg = msg; _downloadProgress = null; });
    HapticFeedback.heavyImpact();
  }

  double get _effectiveProgress {
    if (_currentStep == _Step.download && _downloadProgress != null) {
      return 0.10 + (_downloadProgress! * 0.32);
    }
    return _progressTarget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cycleQuote,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'Assets/images/AURA_load.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // REMOVED THE BLACK GRADIENT POSITIONED WIDGET HERE

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: _errorMsg != null
                      ? _ErrorCard(
                    message: _errorMsg!,
                    onRetry: () {
                      setState(() { _errorMsg = null; });
                      _loadingLock = false;
                      _load();
                    },
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _quoteFade,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF9CEE), Color(0xFFD5A3FF), Color(0xFF90F0DF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            '${_shuffledQuotes[_quoteIndex]}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                      color: Colors.black87, // Slightly darker shadow for visibility on bright backgrounds
                                      blurRadius: 10,
                                      offset: Offset(2, 2)
                                  ),
                                  Shadow(
                                      color: Colors.black87,
                                      blurRadius: 20,
                                      offset: Offset(0, 2)
                                  )
                                ]
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: _effectiveProgress),
                        duration: const Duration(milliseconds: 1600),
                        curve: Curves.easeOut,
                        builder: (_, value, __) => _GreenStripedBar(
                          progress:    value,
                          shimmerCtrl: _shimmerCtrl,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GREEN STRIPED PROGRESS BAR (Liquid Fill) ──────────────────────────────────
class _GreenStripedBar extends StatelessWidget {
  final double              progress;
  final AnimationController shimmerCtrl;
  const _GreenStripedBar({required this.progress, required this.shimmerCtrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fillWidth = maxWidth * progress.clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. The Empty Background Track
            Container(
              height: 24,
              width: maxWidth,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
            ),

            // 2. The Liquid Fill
            Positioned(
              left: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 24,
                  width: fillWidth,
                  child: AnimatedBuilder(
                    animation: shimmerCtrl,
                    builder: (_, __) {
                      return Stack(
                        children: [
                          Positioned(
                            left: -(shimmerCtrl.value * 60),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: maxWidth + 120,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: FractionalOffset(0.0, 0.0),
                                  end: FractionalOffset(0.12, 1.0),
                                  stops: [0.0, 0.5, 0.5, 1.0],
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF4CAF50),
                                    Colors.white,
                                    Colors.white,
                                  ],
                                  tileMode: TileMode.repeated,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. Percentage Text Overlay
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    )
                  ]
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── ERROR CARD ───────────────────────────────────���────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
            ),
            child: const Text('Try again',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}