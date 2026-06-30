import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../src/rust/api/stt.dart' as rust_stt;

part 'stt_model_service_download.dart';

// ── Streaming-STT model cache (first-launch downloader) ──────────────────────
//
// Downloads the ~41.6MB sherpa-onnx streaming-Zipformer 20M int8 model set
// (NOT bundled in the app) into a stable runtime cache, then signals readiness
// so stt_service.dart can pick the sherpa streaming path over the whisper
// fallback. Triggered in the background after the engine becomes ready (see
// AuraBarBrain.setEngineReady) so the chat/bar is usable immediately — voice
// (mic) simply degrades to whisper until the download completes.
//
// Cache layout mirrors the Rust resolve path (api/stt.rs::runtime_cache_dir):
//   ~/.local/share/aura_notebook/stt-20m-int8/
//     ├── encoder-epoch-99-avg-1.int8.onnx   (40.86 MB)
//     ├── decoder-epoch-99-avg-1.int8.onnx   ( 0.51 MB)
//     ├── joiner-epoch-99-avg-1.int8.onnx    ( 0.25 MB)
//     └── tokens.txt                         ( 4.9 KB)
// Each file is written to `<name>.part` then atomically renamed on completion
// (same resilient pattern as loading_screen.dart::_download), with HTTP Range
// resume + retry so a dropped connection mid-download recovers instead of
// restarting the 41MB encoder from zero.
//
// Source: https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17

class SttModelService {
  SttModelService._();
  static final SttModelService instance = SttModelService._();

  static const _kBaseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17/resolve/main';

  static const _kEncoder = 'encoder-epoch-99-avg-1.int8.onnx';
  static const _kDecoder = 'decoder-epoch-99-avg-1.int8.onnx';
  static const _kJoiner = 'joiner-epoch-99-avg-1.int8.onnx';
  static const _kTokens = 'tokens.txt';

  static const int _kEncoderMin = 40 * 1024 * 1024; // 40 MB (real: 40.86 MB)
  static const int _kDecoderMin = 400 * 1024; // (real: 0.51 MB)
  static const int _kJoinerMin = 200 * 1024; // (real: 0.25 MB)
  static const int _kTokensMin = 1024; // (real: 4.9 KB)

  bool _ready = false;
  bool _downloadInFlight = false;
  Completer<bool>? _downloadCompleter;

  final ValueNotifier<bool> isReadyNotifier = ValueNotifier<bool>(false);

  bool get isReady => _ready;

  Future<String?> cacheDir() async {
    try {
      String base;
      if (Platform.isAndroid) {
        final docs = await getApplicationDocumentsDirectory();
        base = docs.path;
      } else if (Platform.isLinux) {
        final dataRoot = Platform.environment['XDG_DATA_HOME'];
        if (dataRoot != null && dataRoot.trim().isNotEmpty) {
          base = dataRoot;
        } else {
          final home = Platform.environment['HOME'];
          if (home == null || home.trim().isEmpty) return null;
          base = '$home/.local/share';
        }
      } else {
        return null;
      }
      final dir = Directory('$base/aura_notebook/stt-20m-int8');
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir.path;
    } catch (e) {
      debugPrint('SttModelService: cacheDir failed: $e');
      return null;
    }
  }

  Future<bool> isPresent() async {
    final dir = await cacheDir();
    if (dir == null) return false;
    bool ok(String name, int minBytes) {
      final f = File('$dir/$name');
      return f.existsSync() && f.lengthSync() >= minBytes;
    }
    return ok(_kEncoder, _kEncoderMin) &&
        ok(_kDecoder, _kDecoderMin) &&
        ok(_kJoiner, _kJoinerMin) &&
        ok(_kTokens, _kTokensMin);
  }

  Future<bool> ensureDownloaded({void Function(double)? onProgress}) async {
    if (Platform.isAndroid) {
      debugPrint('SttModelService: skipping download on Android (voice feature disabled)');
      return false;
    }
    if (_ready) return true;
    if (_downloadInFlight && _downloadCompleter != null) {
      return _downloadCompleter!.future;
    }

    _downloadInFlight = true;
    _downloadCompleter = Completer<bool>();
    try {
      if (await isPresent()) {
        await _markReady();
        return true;
      }

      final dir = await cacheDir();
      if (dir == null) {
        debugPrint('SttModelService: no cache dir — skipping download');
        return false;
      }

      debugPrint('SttModelService: downloading int8 STT model to $dir');
      const files = <(String, int)>[
        (_kEncoder, _kEncoderMin),
        (_kDecoder, _kDecoderMin),
        (_kJoiner, _kJoinerMin),
        (_kTokens, _kTokensMin),
      ];

      final totalWeight = files.fold<int>(0, (s, f) => s + f.$2);
      var doneWeight = 0;
      for (final (name, minBytes) in files) {
        final dest = '$dir/$name';
        final f = File(dest);
        if (f.existsSync() && f.lengthSync() >= minBytes) {
          doneWeight += minBytes;
          onProgress?.call((doneWeight / totalWeight).clamp(0.0, 1.0));
          continue;
        }
        try {
          await _downloadFile('$_kBaseUrl/$name', dest, minBytes);
        } catch (e) {
          debugPrint('SttModelService: download FAILED for $name: $e');
          final part = File('$dest.part');
          if (part.existsSync()) {
            try { await part.delete(); } catch (_) {}
          }
          return false;
        }
        doneWeight += minBytes;
        onProgress?.call((doneWeight / totalWeight).clamp(0.0, 1.0));
      }

      if (await isPresent()) {
        debugPrint('SttModelService: download complete — initializing sherpa engine...');
        await _markReady();
        return _ready;
      }
      debugPrint('SttModelService: download finished but presence check failed');
      return false;
    } finally {
      _downloadInFlight = false;
      final c = _downloadCompleter;
      _downloadCompleter = null;
      if (c != null && !c.isCompleted) c.complete(_ready);
    }
  }

  Future<void> _markReady() async {
    if (Platform.isLinux) {
      try {
        final ok = await rust_stt.auraSttInit();
        debugPrint('SttModelService: post-download auraSttInit() → $ok');
        if (!ok) {
          debugPrint('SttModelService: auraSttInit failed — NOT marking ready');
          return;
        }
      } catch (e) {
        debugPrint('SttModelService: post-download auraSttInit() error: $e');
        return;
      }
    }
    _ready = true;
    if (!isReadyNotifier.value) isReadyNotifier.value = true;
  }

  Future<void> refreshFromDisk() async {
    final present = await isPresent();
    _ready = present;
    if (isReadyNotifier.value != present) isReadyNotifier.value = present;
  }
}
