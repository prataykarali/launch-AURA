part of 'main.dart';

extension _LoadingScreenReadinessLogic on _LoadingScreenState {
  Future<bool> _validateChatModelPath(
    String modelPath,
    List<String> cleanupDirs,
  ) async {
    if (_isExpectedChatModel(modelPath)) {
      await _removeStaleModelFiles(cleanupDirs, modelPath);
      debugPrint('[AURA-MODEL] using chat model: $modelPath');
      return true;
    }
    debugPrint('[AURA-MODEL] refusing unexpected chat model path: $modelPath');
    return false;
  }

  Future<_ReadinessState> _awaitReadiness() async {
    final readiness = _ReadinessState()..model = true;

    // Step 1: Check buffer/memory status — must run first (sets backend flag).
    try {
      final status = await auraGetBufferStatus().timeout(
        const Duration(seconds: 8),
      );
      readiness.memory =
          status.trim().isNotEmpty && !status.toLowerCase().contains('error');
      readiness.backend = readiness.memory;
    } catch (e) {
      debugPrint('AURA readiness: memory/backend check failed: $e');
    }

    // Step 2: TTS init, STT init, and asset preload run in parallel — they
    // have no data dependency on each other. This cuts sequential wait time
    // from up to ~37 s down to ~12 s (the longest individual branch).
    // Note: AuraTTSService.init() already polls _warmupAndroidTts() internally
    // (tts_service.dart), so no separate _waitForAndroidTtsReady() is needed.
    await Future.wait([
      // TTS branch
      () async {
        try {
          await AuraTTSService.instance.init().timeout(
            const Duration(seconds: 12),
          );
          readiness.tts = true;
        } catch (e) {
          debugPrint('AURA readiness: TTS init failed: $e');
        }
      }(),
      // STT branch
      () async {
        try {
          readiness.stt = await AuraSTTService.instance.init().timeout(
            const Duration(seconds: 12),
          );
        } catch (e) {
          debugPrint('AURA readiness: STT init failed: $e');
        }
      }(),
      // Asset preload branch
      () async {
        try {
          await Future.wait([
            rootBundle.load('Assets/images/AURA_load.png'),
            rootBundle.load('Assets/images/balloon2.png'),
          ]).timeout(const Duration(seconds: 5));
          readiness.characterAssets = true;
        } catch (e) {
          debugPrint('AURA readiness: character asset preload failed: $e');
        }
      }(),
    ]);

    // Step 3: Android overlay — runs after TTS is ready (needs mute flag).
    if (Platform.isAndroid) {
      try {
        await AndroidOverlayService.showBar(
          muted: AuraBarBrain.instance.isMuted,
        ).timeout(const Duration(seconds: 20));
        readiness.platformServices = await AndroidOverlayService.isActive()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('AURA readiness: Android platform services failed: $e');
      }
    } else {
      readiness.platformServices = true;
    }

    return readiness;
  }
}
