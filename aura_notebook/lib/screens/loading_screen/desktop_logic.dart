part of 'main.dart';

extension _LoadingScreenDesktopLogic on _LoadingScreenState {
  Future<_ModelPaths?> _loadDesktop({required String appDocsDir}) async {
    // Desktop: read the GGUF and embedder directly from the bundle / source
    // assets dir (no multi-hundred-MB memory copy). The model + embedder are
    // no longer bundled in the APK, so resolve them via the candidate walk that
    // covers the built bundle, the cwd-relative assets dir, and the absolute
    // source fallback.
    final executable = Platform.resolvedExecutable;
    final exeDir = File(executable).parent.path;
    final assetBase = '$exeDir/data/flutter_assets/assets';

    final tokPath = '$assetBase/$_kTokenizerFilename';

    // Resolve embedder from source dirs (same pattern as GGUF).
    var embedPath =
        (await _resolveDesktopFile(
          'embedder/model_quantized.onnx',
          assetBase,
          _kEmbedMinBytes,
        )) ??
        '';
    var embedTokPath =
        (await _resolveDesktopFile(
          'embedder/tokenizer.json',
          assetBase,
          1024,
        )) ??
        '';
    if (embedPath.isEmpty || embedTokPath.isEmpty) {
      // Fallback: try the assetBase directly even if below minBytes
      // (covers the case where the file exists but is a different model).
      embedPath = '$assetBase/embedder/model_quantized.onnx';
      embedTokPath = '$assetBase/embedder/tokenizer.json';
    }

    var modelPath = (await _resolveDesktopModelPath(assetBase)) ?? '';
    if (modelPath.isEmpty) {
      // Not found anywhere on disk — fall back to a one-time download into
      // the user's models dir so desktop dev still works without a manual
      // copy. (Production desktop should ship the GGUF in the bundle.)
      final dir = await PathManager.getModelsDir();
      await Directory(dir).create(recursive: true);
      modelPath = '$dir/$_kModelFilename';
    }
    if (!_isExpectedChatModel(modelPath) &&
        modelPath.endsWith('/$_kModelFilename')) {
      _setStep(_Step.download);
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _download(_kModelUrl, modelPath);
      } catch (e) {
        if (File(modelPath).existsSync()) await File(modelPath).delete();
        final hint = await _storageHint(modelPath);
        _setError('Chat model download failed:\n$e$hint');
        _loadingLock = false;
        return null;
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }
    final cleanupDirs = <String>[
      File(modelPath).parent.path,
      assetBase,
      '$appDocsDir/models',
      appDocsDir,
    ];
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      cleanupDirs.addAll([
        '${appSupportDir.path}/files/models',
        '${appSupportDir.path}/models',
        appSupportDir.path,
      ]);
    } catch (e) {
      debugPrint('[AURA-MODEL] app support cleanup path unavailable: $e');
    }
    if (!await _validateChatModelPath(modelPath, cleanupDirs)) {
      final hint = await _storageHint(modelPath);
      _setError(
        'Chat model not found. Expected $_kModelFilename, but startup resolved:\n$modelPath$hint',
      );
      _loadingLock = false;
      return null;
    }

    debugPrint('Using model from: $modelPath, embedder from: $embedPath');

    return (
      modelPath: modelPath,
      tokPath: tokPath,
      embedPath: embedPath,
      embedTokPath: embedTokPath,
    );
  }
}
