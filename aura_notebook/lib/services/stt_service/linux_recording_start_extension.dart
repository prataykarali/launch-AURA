part of 'aura_stt_service.dart';

// ── Rust sherpa streaming path (env override) ─────────────────────────────
extension _AuraSTTServiceLinuxStart on AuraSTTService {
  Future<void> _startRustListening({
    required Function(String text, bool isFinal) onResult,
    required VoidCallback onError,
  }) async {
    if (_isLinuxListening) return;
    _killLinuxRecorder();

    _isLinuxListening = true;
    isListeningNotifier.value = true;
    soundLevelNotifier.value = 0.0;

    await rust_stt.auraSttResetSession();
    final gen = _recordGeneration;

    try {
      // arecord -t raw -f S16_LE -r 16000 -c 1
      final p = await Process.start('arecord', [
        '-q',
        '-t',
        'raw',
        '-f',
        'S16_LE',
        '-r',
        '16000',
        '-c',
        '1',
      ]);

      if (gen != _recordGeneration) {
        p.kill(ProcessSignal.sigkill);
        return;
      }
      _recordProcess = p;

      _sttStdoutSub = p.stdout.listen((bytes) {
        if (gen != _recordGeneration) return;
        if (bytes.isEmpty) return;

        final byteData = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
        final sampleCount = byteData.length ~/ 2;

        // Convert Int16 PCM to Float32 samples
        final samples = List<double>.filled(sampleCount, 0.0);
        var rmsSum = 0.0;

        for (var i = 0; i < sampleCount; i++) {
          final u16 = byteData[i * 2] | (byteData[i * 2 + 1] << 8);
          final s16 = u16 >= 0x8000 ? u16 - 0x10000 : u16;
          final norm = s16 / 32768.0;
          samples[i] = norm;
          rmsSum += norm * norm;
        }

        final rms = sampleCount > 0 ? (rmsSum / sampleCount) : 0.0;
        final level = (rms * 6.0).clamp(0.0, 1.0);
        soundLevelNotifier.value = level;
        _soundLevelController.add(level);

        _rustAudioBucket.tryAdd(
          _RustAudioChunk(generation: gen, samples: samples),
          (chunk) async {
            if (chunk.generation != _recordGeneration ||
                !ResourceGuardService.instance.shouldAcceptSensoryWork) {
              return;
            }
            try {
              final resultText = await rust_stt.auraSttPushAudio(
                samples: chunk.samples,
                sampleRate: 16000,
              );
              if (resultText.isNotEmpty) {
                onResult(resultText, false);
              }
            } catch (e) {
              debugPrint('AuraSTT Rust push audio error: $e');
            }
          },
        );
      });

      p.exitCode.then((_) {
        if (gen != _recordGeneration) return;
        soundLevelNotifier.value = 0.0;
        _isLinuxListening = false;
        isListeningNotifier.value = false;
      });
    } catch (e) {
      debugPrint('AuraSTT Rust arecord error: $e');
      _isLinuxListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      onError();
    }
  }

  void _writeWavHeader(RandomAccessFile file, int numBytes) {
    final header = Uint8List(44);
    final view = ByteData.sublistView(header);

    // "RIFF"
    header.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
    // File size - 8
    view.setUint32(4, numBytes + 36, Endian.little);
    // "WAVE"
    header.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]);
    // "fmt "
    header.setRange(12, 16, [0x66, 0x6d, 0x74, 0x20]);
    // Subchunk1Size (16)
    view.setUint32(16, 16, Endian.little);
    // AudioFormat (1 = PCM)
    view.setUint16(20, 1, Endian.little);
    // NumChannels (1)
    view.setUint16(22, 1, Endian.little);
    // SampleRate (16000)
    view.setUint32(24, 16000, Endian.little);
    // ByteRate (16000 * 2 = 32000)
    view.setUint32(28, 32000, Endian.little);
    // BlockAlign (2)
    view.setUint16(32, 2, Endian.little);
    // BitsPerSample (16)
    view.setUint16(34, 16, Endian.little);
    // "data"
    header.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]);
    // Data size
    view.setUint32(40, numBytes, Endian.little);

    file.setPositionSync(0);
    file.writeFromSync(header);
  }

  // ── Linux: start listening via arecord → WAV ─────────────────────────────
  Future<void> _startLinuxListening({
    required Function(String text, bool isFinal) onResult,
    required VoidCallback onError,
  }) async {
    if (_isLinuxListening) {
      debugPrint('STT Linux: already listening — ignoring duplicate start');
      return;
    }

    _killLinuxRecorder();

    // Ensure the whisper server is (being) started.
    unawaited(_ensureWhisperServer());

    _isLinuxListening = true;
    isListeningNotifier.value = true;
    soundLevelNotifier.value = 0.0;

    // Create a temp WAV file in /tmp.
    final wavPath =
        '/tmp/aura_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentWavPath = wavPath;

    final gen = _recordGeneration;

    try {
      // Record raw PCM format so we can process and write it manually
      final p = await Process.start('arecord', [
        '-q',
        '-t',
        'raw',
        '-f',
        'S16_LE',
        '-r',
        '16000',
        '-c',
        '1',
      ], mode: ProcessStartMode.normal);

      if (gen != _recordGeneration) {
        p.kill(ProcessSignal.sigkill);
        try {
          await File(wavPath).delete();
        } catch (_) {}
        return;
      }
      _recordProcess = p;

      var recorderFailed = false;
      p.stderr.transform(const SystemEncoding().decoder).listen((data) {
        final msg = data.trim();
        if (msg.isNotEmpty) debugPrint('STT Linux [arecord stderr]: $msg');
        if (msg.isNotEmpty) recorderFailed = true;
      });

      // Write PCM bytes to the WAV file and calculate RMS sound level.
      final file = await File(wavPath).open(mode: FileMode.write);
      _writeWavHeader(file, 0);
      var totalBytes = 0;

      _sttStdoutSub = p.stdout.listen((bytes) {
        if (gen != _recordGeneration) return;
        if (bytes.isEmpty) return;

        file.writeFromSync(bytes);
        totalBytes += bytes.length;

        final byteData = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
        final sampleCount = byteData.length ~/ 2;
        var rmsSum = 0.0;
        for (var i = 0; i < sampleCount; i++) {
          final u16 = byteData[i * 2] | (byteData[i * 2 + 1] << 8);
          final s16 = u16 >= 0x8000 ? u16 - 0x10000 : u16;
          final norm = s16 / 32768.0;
          rmsSum += norm * norm;
        }
        final rms = sampleCount > 0 ? (rmsSum / sampleCount) : 0.0;
        final level = (rms * 6.0).clamp(0.0, 1.0);
        soundLevelNotifier.value = level;
        _soundLevelController.add(level);
      });

      // The arecord process exits when killed in finalizeListening().
      p.exitCode.then((_) async {
        try {
          _writeWavHeader(file, totalBytes);
          await file.close();
        } catch (e) {
          debugPrint('STT Linux: error finalizing WAV file: $e');
        }
        if (gen != _recordGeneration) return;
        soundLevelNotifier.value = 0.0;
        _isLinuxListening = false;
        isListeningNotifier.value = false;
        if (recorderFailed && totalBytes == 0) {
          _currentWavPath = null;
          onError();
        }
      });
    } catch (e) {
      debugPrint('STT Linux: arecord start error: $e');
      _isLinuxListening = false;
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
      _currentWavPath = null;
      onError();
    }
  }

  // ── Linux: kill any in-flight recorder ───────────────────────────────────
  void _killLinuxRecorder() {
    final p = _recordProcess;
    _recordProcess = null;
    _killProcess(p);

    _recordGeneration++;
    _rustAudioBucket.clear();
    _sttStdoutSub?.cancel();
    _sttStdoutSub = null;
    soundLevelNotifier.value = 0.0;
  }
}

class _RustAudioChunk {
  const _RustAudioChunk({required this.generation, required this.samples});

  final int generation;
  final List<double> samples;
}
