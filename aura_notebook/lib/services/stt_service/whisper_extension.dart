part of 'aura_stt_service.dart';

// ── Whisper server management ─────────────────────────────────────────────
extension _AuraSTTServiceWhisper on AuraSTTService {
  /// Find the whisper_server.py bundled with the app.
  String? _findWhisperScript() {
    // 1. Beside the executable (production bundle)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/data/flutter_assets/assets/whisper_server.py',
      // 2. Source tree (dev mode)
      '${Directory.current.path}/assets/whisper_server.py',
      // 3. Hardcoded dev path
      '/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/whisper_server.py',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  Future<void> _ensureWhisperServer() async {
    if (_whisperReady || _whisperStarting) return;
    _whisperStarting = true;

    if (Platform.isLinux) {
      try {
        debugPrint(
          '[AURA_WHISPER] Cleaning up orphaned whisper_server.py processes...',
        );
        await Process.run('pkill', ['-f', 'whisper_server.py']);
      } catch (e) {
        debugPrint(
          '[AURA_WHISPER] Failed to pkill existing whisper servers: $e',
        );
      }
    }

    final script = _findWhisperScript();
    if (script == null) {
      debugPrint(
        '[AURA_WHISPER] whisper_server.py not found — falling back to sherpa',
      );
      _missingDependency = 'whisper-script';
      missingDependencyNotifier.value = _missingDependency;
      _whisperStarting = false;
      return;
    }

    // Check that python3 + openai-whisper are available.
    try {
      final check = await Process.run('python3', ['-c', 'import whisper']);
      if (check.exitCode != 0) {
        debugPrint(
          '[AURA_WHISPER] openai-whisper not installed: ${check.stderr}',
        );
        _missingDependency = 'openai-whisper';
        missingDependencyNotifier.value = _missingDependency;
        _whisperStarting = false;
        return;
      }
    } catch (e) {
      debugPrint('[AURA_WHISPER] python3 not found: $e');
      _missingDependency = 'python3';
      missingDependencyNotifier.value = _missingDependency;
      _whisperStarting = false;
      return;
    }

    debugPrint(
      '[AURA_WHISPER] Starting whisper server (base multilingual on GPU)...',
    );
    try {
      _whisperServer = await Process.start(
        'python3',
        ['-u', script],
        environment: {...Platform.environment, 'AURA_WHISPER_MODEL': 'base'},
      );

      _whisperStderrSub = _whisperServer!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) {
              debugPrint('[AURA_WHISPER_PY] ${line.trim()}');
            }
          });

      // Subscribe to server stdout to receive READY / RESULT / ERROR lines.
      _whisperStdoutSub =
          (_whisperServer!.stdout
                  .transform(const SystemEncoding().decoder)
                  .transform(LineSplitter()))
              .listen(
                (line) {
                  final trimmed = line.trim();
                  if (trimmed.isEmpty) return;
                  debugPrint('[AURA_WHISPER] ← $trimmed');

                  if (trimmed == 'READY') {
                    _whisperReady = true;
                    _whisperStarting = false;
                    _clearMissingDependency();
                    debugPrint(
                      '[AURA_WHISPER] Server ready — whisper-base multilingual loaded on GPU',
                    );
                    return;
                  }

                  // Dispatch to the oldest pending completer.
                  if (_whisperPending.isNotEmpty) {
                    final completer = _whisperPending.removeAt(0);
                    if (trimmed.startsWith('RESULT:')) {
                      completer.complete(
                        trimmed.substring('RESULT:'.length).trim(),
                      );
                    } else if (trimmed.startsWith('ERROR:')) {
                      completer.completeError(
                        trimmed.substring('ERROR:'.length).trim(),
                      );
                    } else {
                      completer.complete(
                        '',
                      ); // unexpected line — treat as empty
                    }
                  }
                },
                onError: (e) {
                  debugPrint('[AURA_WHISPER] stdout error: $e');
                },
                onDone: () {
                  debugPrint('[AURA_WHISPER] Server process exited');
                  _whisperReady = false;
                  _whisperStarting = false;
                  _whisperServer = null;
                  // Fail any pending requests.
                  for (final c in _whisperPending) {
                    if (!c.isCompleted) c.complete('');
                  }
                  _whisperPending.clear();
                },
              );
      unawaited(
        _whisperServer!.exitCode.then((code) {
          debugPrint('[AURA_WHISPER] process exited with code $code');
          _whisperReady = false;
          _whisperStarting = false;
          _whisperServer = null;
        }),
      );
    } catch (e) {
      debugPrint('[AURA_WHISPER] Failed to start server: $e');
      _whisperReady = false;
      _whisperStarting = false;
    }
  }

  /// Send a WAV path to the whisper server and await the transcription.
  Future<String> _transcribeWav(String wavPath) async {
    if (!ResourceGuardService.instance.shouldAcceptSensoryWork) {
      debugPrint('[AURA_WHISPER] health guard active — skipping transcription');
      return '';
    }
    if (_whisperPending.length >= AuraSTTService._kMaxWhisperPending) {
      debugPrint(
        '[AURA_WHISPER] transcription bucket full — dropping stale request',
      );
      return '';
    }

    // Wait up to 30s for the server to become ready (first load takes ~8-10s on GPU).
    const kMaxWait = Duration(seconds: 30);
    final deadline = DateTime.now().add(kMaxWait);
    while (!_whisperReady) {
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('[AURA_WHISPER] Timed out waiting for server to be ready');
        return '';
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final completer = Completer<String>();
    _whisperPending.add(completer);

    debugPrint('[AURA_WHISPER] → $wavPath');
    try {
      _whisperServer!.stdin.writeln(wavPath);
      await _whisperServer!.stdin.flush();
    } catch (e) {
      debugPrint('[AURA_WHISPER] stdin write error: $e');
      _whisperPending.remove(completer);
      if (!completer.isCompleted) completer.complete('');
      return '';
    }

    try {
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('[AURA_WHISPER] Transcription timeout');
          _whisperPending.remove(completer);
          return '';
        },
      );
    } catch (e) {
      debugPrint('[AURA_WHISPER] Transcription error: $e');
      return '';
    }
  }
}
