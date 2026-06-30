part of 'main.dart';

extension _LoadingScreenDownloadLogic on _LoadingScreenState {
  Future<void> _download(String url, String destPath) async {
    await File(destPath).parent.create(recursive: true);

    // On Android, use the native download channel (aura/download) which goes
    // through Java's InetAddress + HttpURLConnection — this uses the Android
    // system DNS resolver that actually works on cellular networks where Dart's
    // InternetAddress.lookup fails (proven: adb shell ping resolves fine but
    // Dart gets "No address associated with hostname").
    if (Platform.isAndroid) {
      const dlChannel = MethodChannel('aura/download');
      // Listen for progress events from the native side.
      const progressChannel = EventChannel('aura/download/progress');
      final progressSub = progressChannel.receiveBroadcastStream().listen((
        event,
      ) {
        if (event is double) {
          _updateState(() => _downloadProgress = event);
        }
      });
      try {
        final ok = await dlChannel.invokeMethod<bool>('downloadFile', {
          'url': url,
          'destPath': destPath,
        });
        if (ok != true) {
          throw Exception('Native download returned failure');
        }
      } finally {
        progressSub.cancel();
      }
      return;
    }

    // Desktop / iOS: use Dart's HttpClient (DNS works fine on these platforms).
    final partFile = File('$destPath.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    int attempt = 0;
    const maxAttempts = 5;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        final startBytes = partFile.existsSync() ? partFile.lengthSync() : 0;
        final uri = Uri.parse(url);

        final req = await client.getUrl(uri);
        req.headers.set('User-Agent', 'Mozilla/5.0');
        if (startBytes > 0) {
          req.headers.set('Range', 'bytes=$startBytes-');
        }
        req.followRedirects = true;
        req.maxRedirects = 8;
        final response = await req.close();

        final isResume = response.statusCode == 206;
        if (response.statusCode != 200 && response.statusCode != 206) {
          if (response.statusCode == 416) {
            if (partFile.existsSync()) await partFile.delete();
            throw Exception('Range not satisfiable, resetting download');
          }
          throw Exception('Server returned status code ${response.statusCode}');
        }

        final totalContentLength = response.contentLength;
        final totalBytes = isResume
            ? (startBytes + totalContentLength)
            : totalContentLength;

        final sink = partFile.openWrite(
          mode: isResume ? FileMode.append : FileMode.write,
        );
        int received = isResume ? startBytes : 0;

        try {
          await for (final chunk in response) {
            sink.add(chunk);
            received += chunk.length;
            if (totalBytes > 0) {
              _updateState(() => _downloadProgress = received / totalBytes);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (totalBytes <= 0 || received >= totalBytes) {
          break;
        } else {
          throw Exception(
            'Incomplete download: received $received of $totalBytes bytes',
          );
        }
      } catch (e) {
        debugPrint('Download attempt $attempt failed: $e');
        if (attempt >= maxAttempts) {
          client.close(force: true);
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    client.close(force: true);

    // On success, rename the .part file to destPath
    final destFile = File(destPath);
    if (destFile.existsSync()) {
      await destFile.delete();
    }
    await partFile.rename(destPath);
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyAssetToFile(String assetPath, String outPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final file = File(outPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _copyFileToPrivatePath(
    String sourcePath,
    String destPath, {
    int minBytes = 1,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw FileSystemException('Source file not found', sourcePath);
    }
    if (source.absolute.path == File(destPath).absolute.path) return;

    final sourceLen = source.lengthSync();
    if (sourceLen < minBytes) {
      throw FileSystemException(
        'Source file is incomplete ($sourceLen bytes)',
        sourcePath,
      );
    }

    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    final part = File('$destPath.part');
    if (part.existsSync()) await part.delete();

    final sink = part.openWrite();
    var copied = 0;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        copied += chunk.length;
        if (sourceLen > 0) {
          _updateState(() => _downloadProgress = copied / sourceLen);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (part.lengthSync() < minBytes) {
      await part.delete();
      throw FileSystemException('Copied file is incomplete', part.path);
    }
    if (dest.existsSync()) await dest.delete();
    await part.rename(destPath);
  }

  Future<void> _ensureFiles({
    required String modelPath,
    required String tokPath,
    required String embedPath,
    required String embedTokPath,
    required bool requireEmbed,
  }) async {
    final modelFile = File(modelPath);
    final tokFile = File(tokPath);
    final embedFile = File(embedPath);
    final embedTokFile = File(embedTokPath);

    final modelOk =
        modelFile.existsSync() && modelFile.lengthSync() > _kModelMinBytes;
    final tokOk = tokFile.existsSync() && tokFile.lengthSync() > 1024;
    final embedOk =
        embedFile.existsSync() && embedFile.lengthSync() > 100 * 1024 * 1024;
    final embedTokOk =
        embedTokFile.existsSync() && embedTokFile.lengthSync() > 1024;

    if (modelOk && tokOk && (!requireEmbed || (embedOk && embedTokOk))) return;
    _setStep(_Step.prepare);

    final hasModelAsset = await _assetExists(_kModelAssetPath);
    final hasTokAsset = await _assetExists(_kTokenizerAssetPath);
    final hasEmbedAsset = requireEmbed && await _assetExists(_kEmbedAssetPath);
    final hasEmbedTokAsset =
        requireEmbed && await _assetExists(_kEmbedTokAssetPath);

    if (!modelOk && hasModelAsset) {
      await _copyAssetToFile(_kModelAssetPath, modelPath);
    }
    if (!tokOk && hasTokAsset) {
      await _copyAssetToFile(_kTokenizerAssetPath, tokPath);
    }
    if (requireEmbed && !embedOk && hasEmbedAsset) {
      await _copyAssetToFile(_kEmbedAssetPath, embedPath);
    }
    if (requireEmbed && !embedTokOk && hasEmbedTokAsset) {
      await _copyAssetToFile(_kEmbedTokAssetPath, embedTokPath);
    }

    final modelOk2 =
        modelFile.existsSync() && modelFile.lengthSync() > _kModelMinBytes;
    final tokOk2 = tokFile.existsSync() && tokFile.lengthSync() > 1024;
    final embedOk2 =
        embedFile.existsSync() && embedFile.lengthSync() > _kEmbedMinBytes;
    final embedTokOk2 =
        embedTokFile.existsSync() && embedTokFile.lengthSync() > 1024;

    if (modelOk2 && tokOk2 && (!requireEmbed || (embedOk2 && embedTokOk2))) {
      return;
    }

    // On Android/iOS, model & tokenizer are bundled as assets — no download needed
    // On desktop, we may need to download embedder assets if missing
    if (!requireEmbed) {
      _setError(
        'Model/tokenizer not found in assets. Please ensure they are bundled.',
      );
      return;
    }

    _setStep(_Step.download);

    if (requireEmbed && !embedOk2) {
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _download(_kEmbedModelUrl, embedPath);
      } catch (e) {
        if (embedFile.existsSync()) embedFile.deleteSync();
        rethrow;
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }
    if (requireEmbed && !embedTokOk2) {
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _download(_kEmbedTokUrl, embedTokPath);
      } catch (e) {
        if (embedTokFile.existsSync()) embedTokFile.deleteSync();
        rethrow;
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }
  }
}
