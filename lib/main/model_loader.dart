part of '../main.dart';

// ── MODEL LOADER ──────────────────────────────────────────────────────────────
class _ModelLoader extends StatefulWidget {
  const _ModelLoader();
  @override
  State<_ModelLoader> createState() => _ModelLoaderState();
}

class _ModelLoaderState extends State<_ModelLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  _Step _currentStep = _Step.wake;
  String? _errorMsg;
  double? _downloadProgress;
  bool _loadingLock = false;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _download(String url, String destPath) async {
    Uri uri = Uri.parse(url);
    HttpClientResponse? response;
    final client = HttpClient();

    for (int i = 0; i < 5; i++) {
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      response = await req.close();

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
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
      throw Exception('HTTP ${response?.statusCode} for $url');
    }

    final total = response.contentLength;
    final sink = File(destPath).openWrite();
    int received = 0;

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

      final dir = await PathManager.getModelsDir();
      final modelPath = '$dir/$_kModelFilename';
      final tokPath = '$dir/$_kTokenizerFilename';

      final modelFile = File(modelPath);
      final modelExists =
          modelFile.existsSync() && modelFile.lengthSync() > 200 * 1024 * 1024;

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

      final tokFile = File(tokPath);
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
        _setError('Engine failed to start.\nCheck model file integrity.');
        _loadingLock = false;
        return;
      }

      _setStep(_Step.ready);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const home()));
    } catch (e, st) {
      _setError('Unexpected error:\n$e');
      debugPrint('$e\n$st');
      _loadingLock = false;
    }
  }

  void _setStep(_Step step) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _errorMsg = null;
      _downloadProgress = null;
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMsg = msg;
      _downloadProgress = null;
    });
    HapticFeedback.heavyImpact();
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
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: child,
                ),
                child: Image.asset('Assets/images/balloon2.png', height: 130),
              ),
              const SizedBox(height: 28),
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
              if (_errorMsg != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFF991A66),
                        size: 32,
                      ),
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
                )
              else if (_downloadProgress != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        _currentStep == _Step.download
                            ? 'Downloading model (~235 MB)'
                            : 'Downloading tokenizer...',
                        style: const TextStyle(
                          color: Color(0xFF991A66),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          minHeight: 8,
                          backgroundColor: Colors.indigo.shade50,
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF991A66),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${((_downloadProgress ?? 0) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.indigo.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _StepList(currentStep: _currentStep),
            ],
          ),
        ),
      ),
    );
  }
}
