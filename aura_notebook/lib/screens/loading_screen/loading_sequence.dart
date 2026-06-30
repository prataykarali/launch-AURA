part of 'main.dart';

extension _LoadingScreenSequence on _LoadingScreenState {
  Future<void> _load() async {
    if (_loadingLock) return;
    _loadingLock = true;
    final startTime = DateTime.now();

    // Request microphone permission on startup on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final status = await Permission.microphone.request();
        debugPrint('AURA Startup: Microphone permission status = $status');
      } catch (e) {
        debugPrint('AURA Startup: Error requesting microphone permission: $e');
      }
    }

    _setStep(_Step.wake);
    // No artificial delay here — proceed immediately to actual work.

    // Guard against double-init when running inside desktop_multi_window child.
    // Android still needs FRB before auraInit/auraChat; the async pre-warm in
    // main.dart is opportunistic and may not have completed by this point.
    try {
      await RustLib.init();
    } catch (e) {
      if (!e.toString().contains('initialize flutter_rust_bridge twice')) {
        rethrow;
      }
    }

    try {
      _setStep(_Step.check);
      // Skip the artificial 600ms delay — jump straight to file discovery.

      // Get the app documents directory directly
      final appDocsDir = await getApplicationDocumentsDirectory();
      await Directory(appDocsDir.path).create(recursive: true);

      // The Rust engine HARD-requires the dedicated bge embedder
      // (engine.rs: "dedicated embedder is required for the memory
      // architecture"). If we pass empty embed paths, the worker fails to
      // construct the LlamaEngine and EVERY chat returns
      // "Error: LLM Engine not loaded". So the embedder must be provisioned on
      // ALL native platforms — Android included — even though the chat model
      // itself doesn't need it.
      final requireEmbed =
          Platform.isAndroid ||
          Platform.isLinux ||
          Platform.isWindows ||
          Platform.isMacOS;

      late final String modelPath;
      late final String tokPath;
      late final String embedPath;
      late final String embedTokPath;

      if (_kUseAssetDirectly) {
        final paths = await _loadDesktop(appDocsDir: appDocsDir.path);
        if (paths == null) return;
        modelPath = paths.modelPath;
        tokPath = paths.tokPath;
        embedPath = paths.embedPath;
        embedTokPath = paths.embedTokPath;
      } else if (Platform.isAndroid) {
        final paths = await _loadAndroid(appDocsDir: appDocsDir.path);
        if (paths == null) return;
        modelPath = paths.modelPath;
        tokPath = paths.tokPath;
        embedPath = paths.embedPath;
        embedTokPath = paths.embedTokPath;
      } else {
        final paths = await _loadIos(
          appDocsDir: appDocsDir.path,
          requireEmbed: requireEmbed,
        );
        if (paths == null) return;
        modelPath = paths.modelPath;
        tokPath = paths.tokPath;
        embedPath = paths.embedPath;
        embedTokPath = paths.embedTokPath;
      }

      _setStep(_Step.embed);
      _setStep(_Step.engine);

      // Begin the visible warmup creep ONLY now — auraInit below now genuinely
      // blocks until the model is loaded + the system prompt is prefilled (it
      // used to return instantly while that work happened in the background).
      _startWarmupCreep();

      // auraInit now BLOCKS until the Rust worker has loaded the model, run
      // warmup() (system-prompt prefill) and initialized STT. Wrap it in a
      // hard timeout so a wedged build shows an error instead of hanging.
      bool ok;
      try {
        // Android (especially low-end Samsung devices) can take several
        // minutes to load the 700MB GGUF on CPU and run the first warmup.
        // Give it a longer leash than desktop.
        final initTimeout = Platform.isAndroid
            ? const Duration(seconds: 300)
            : const Duration(seconds: 150);
        ok =
            await auraInit(
              modelPath: modelPath,
              tokenizerPath: tokPath,
              embedModelPath: requireEmbed ? embedPath : '',
              embedTokPath: requireEmbed ? embedTokPath : '',
            ).timeout(
              initTimeout,
              onTimeout: () {
                debugPrint('auraInit timed out after ${initTimeout.inSeconds}s');
                return false;
              },
            );
      } catch (e) {
        _stopWarmupCreep();
        _setError('Engine failed to start:\n$e');
        _loadingLock = false;
        return;
      }
      _stopWarmupCreep();

      if (!ok) {
        _setError('Engine failed to start.');
        _loadingLock = false;
        return;
      }

      _setStep(_Step.services);
      final readiness = await _awaitReadiness();
      // Log warnings for optional subsystems that failed — do NOT block startup.
      if (readiness.warnings.isNotEmpty) {
        debugPrint(
          'AURA startup: optional subsystems unavailable (non-fatal): '
          '${readiness.warnings.join(', ')}',
        );
      }
      // Only block on truly required subsystems (model + memory + backend).
      if (!readiness.allReady) {
        _setError(
          'Startup failed: ${readiness.missing.join(', ')} unavailable.\n'
          'Please check your connection and press Try again.',
        );
        _loadingLock = false;
        return;
      }

      _setStep(_Step.ready);
      // Enforce a minimum loading screen visibility of 2.5s using a dynamic remainder delay
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 2500) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      if (!mounted || _errorMsg != null) return;

      // Loading is complete; make sure the AURA bar isn't left stuck in the
      // processing/loading overlay from the earlier model-status pushes.
      AuraBarBrain.instance.clearLoadingOverlay();

      widget.onDone?.call();
    } catch (e, st) {
      _setError('Unexpected error:\n$e');
      debugPrint('$e\n$st');
      _loadingLock = false;
    }
  }
}
