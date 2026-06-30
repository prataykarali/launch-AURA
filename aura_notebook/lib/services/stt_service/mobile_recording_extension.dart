part of 'aura_stt_service.dart';

// ── Mobile: speech_to_text ────────────────────────────────────────────────
extension _AuraSTTServiceMobile on AuraSTTService {
  Future<void> _startMobileListening({
    required Function(String text, bool isFinal) onResult,
    required VoidCallback onError,
  }) async {
    _mobileListenGeneration++;
    final listenGen = _mobileListenGeneration;
    _lastMobileResult = '';
    _mobileFinalResultSeen = false;
    _currentOnError = onError;
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
      bool hasPermission = true;
      if (Platform.isAndroid || Platform.isIOS) {
        if (AuraSTTService.isMainApp) {
          hasPermission = await Permission.microphone.request().isGranted;
        } else {
          hasPermission = await Permission.microphone.isGranted;
        }
      }
      if (!hasPermission) {
        debugPrint('STT Start: Microphone permission denied');
        _missingDependency = 'microphone-permission';
        missingDependencyNotifier.value = _missingDependency;
        _currentOnError = null;
        onError();
        return;
      }
      final isOk = await init();
      if (!isOk) {
        debugPrint('STT Start: Init failed — speech recognition unavailable');
        _missingDependency ??= 'speech-recognizer';
        missingDependencyNotifier.value = _missingDependency;
        _currentOnError = null;
        onError();
        return;
      }
      _clearMissingDependency();
      String? selectedLocaleId;
      try {
        final locales = await _speechToText.locales();
        if (locales.isNotEmpty) {
          final preferred = Platform.localeName.replaceAll('-', '_');
          for (final locale in locales) {
            if (locale.localeId.toLowerCase() == preferred.toLowerCase()) {
              selectedLocaleId = locale.localeId;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('AuraSTT: Error getting locales: $e');
      }
      debugPrint(
        'AuraSTT: Selected localeId for listen(): ${selectedLocaleId ?? "system default"}',
      );

      isListeningNotifier.value = true;
      soundLevelNotifier.value = 0.0;
      debugPrint(
        'AuraSTT: listen() starting platform=${Platform.operatingSystem} '
        'permission=$hasPermission initialized=$_initialized',
      );
      await _speechToText.listen(
        onResult: (result) {
          if (listenGen != _mobileListenGeneration) return;
          _lastMobileResult = result.recognizedWords;
          debugPrint(
            'STT Result: final=${result.finalResult} text="${result.recognizedWords}"',
          );
          if (result.finalResult) {
            _mobileFinalResultSeen = true;
            isListeningNotifier.value = false;
            soundLevelNotifier.value = 0.0;
          }
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          if (listenGen != _mobileListenGeneration) return;
          final norm = (level + 2.0) / 12.0;
          final clamped = norm.clamp(0.0, 1.0);
          soundLevelNotifier.value = clamped;
          _soundLevelController.add(clamped);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: selectedLocaleId,
        ),
      );
      final started = await _waitForMobileListenStart(listenGen);
      if (!started) {
        debugPrint(
          'STT Start: recognizer status lagged after listen(); keeping session active',
        );
        isListeningNotifier.value = true;
      }
    } catch (e) {
      debugPrint('STT listen error: $e');
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      _currentOnError = null;
      onError();
    }
  }

  Future<bool> _waitForMobileListenStart(int listenGen) async {
    final deadline = DateTime.now().add(const Duration(milliseconds: 1800));
    while (DateTime.now().isBefore(deadline)) {
      if (listenGen != _mobileListenGeneration) return false;
      if (_speechToText.isListening) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _speechToText.isListening;
  }
}
