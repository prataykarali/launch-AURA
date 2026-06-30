part of 'main.dart';

extension _LoadingScreenAndroidLogic on _LoadingScreenState {
  Future<_ModelPaths?> _loadAndroid({required String appDocsDir}) async {
    final modelPath = '$appDocsDir/$_kModelFilename';
    final tokPath = '$appDocsDir/$_kTokenizerFilename';
    final embedPath = '$appDocsDir/$_kEmbedFilename';
    final embedTokPath = '$appDocsDir/$_kEmbedTokFilename';

    // ── Provision via adb-pushed or sideloaded files ─────────────────
    // Build a list of candidate directories where the model GGUF might
    // live: the external app-specific dir (getExternalStorageDirectory),
    // hardcoded fallback paths for that dir, common Download locations,
    // the app's internal files dir, and appDocsDir itself. The FIRST
    // candidate containing a valid file wins.
    String? externalDir;
    String? extDirErr;
    try {
      externalDir = (await getExternalStorageDirectory())?.path;
    } catch (e) {
      extDirErr = e.toString();
    }

    // Comprehensive diagnostics — logged AND collected for on-screen
    // display if the model is ultimately not found.
    final diagLog = StringBuffer();
    diagLog.writeln('[AURA-DIAG] appDocsDir=$appDocsDir');
    diagLog.writeln(
      '[AURA-DIAG] externalDir=$externalDir extDirErr=$extDirErr',
    );

    // Build candidate dirs (order = priority)
    final candidateDirs = <String>[
      appDocsDir,
      ?externalDir,
      '/sdcard/Android/data/com.example.aura_notebook/files',
      '/storage/emulated/0/Android/data/com.example.aura_notebook/files',
      '/sdcard/Download',
      '/storage/emulated/0/Download',
      '/data/data/com.example.aura_notebook/files',
    ];
    // De-duplicate while preserving order
    final seen = <String>{};
    candidateDirs.retainWhere((d) => seen.add(d));

    diagLog.writeln('[AURA-DIAG] candidate dirs (${candidateDirs.length}):');

    // ── Scan candidates for model file ──────────────────────────────
    // Keep app-private storage as the canonical engine path. Android's
    // shared Download paths can be visible to Dart while native mmap/open
    // still fails in llama.cpp, producing only NullResult. Treat shared
    // storage as an import source, never as the Rust model path.
    // Also guard against a partial/corrupted canonical copy by comparing
    // its size to the largest source we can find.
    final canonicalModel = File(modelPath);
    int canonicalModelLen = 0;
    if (canonicalModel.existsSync()) {
      canonicalModelLen = canonicalModel.lengthSync();
    }
    int largestSourceLen = canonicalModelLen;
    String? modelSourcePath;
    for (final dir in candidateDirs) {
      final dirObj = Directory(dir);
      if (!dirObj.existsSync()) continue;

      final candidate = File('$dir/$_kModelFilename');
      if (candidate.existsSync()) {
        final len = candidate.lengthSync();
        if (len >= _kModelMinBytes && len > largestSourceLen) {
          largestSourceLen = len;
          modelSourcePath = candidate.path;
        }
      }
    }
    bool modelFound = canonicalModelLen >= _kModelMinBytes;
    if (modelFound) {
      diagLog.writeln(
        '[AURA-DIAG]   ✓ USING private model cache ($canonicalModelLen bytes)',
      );
    }
    if (modelSourcePath != null && modelSourcePath != canonicalModel.absolute.path) {
      diagLog.writeln(
        '[AURA-DIAG]   ✓ larger model source found: $modelSourcePath ($largestSourceLen bytes)',
      );
    }
    // If the canonical copy is smaller than the largest source, re-import it.
    // This fixes stalled/partial downloads that pass the min-size check.
    if (modelSourcePath != null &&
        modelSourcePath != canonicalModel.absolute.path &&
        canonicalModelLen < largestSourceLen) {
      _setStep(_Step.prepare);
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _copyFileToPrivatePath(
          modelSourcePath,
          modelPath,
          minBytes: _kModelMinBytes,
        );
        modelFound = true;
        canonicalModelLen = largestSourceLen;
        diagLog.writeln(
          '[AURA-DIAG]   ✓ RE-IMPORTED model to private cache ($canonicalModelLen bytes)',
        );
      } catch (e) {
        debugPrint('Model re-import failed: $e');
        // Keep whatever we have; engine init will fail if it's truly unusable.
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }

    // ── Scan candidates for embedder files ─────────────────────────
    bool embedFound =
        File(embedPath).existsSync() &&
        File(embedPath).lengthSync() >= _kEmbedMinBytes;
    String? embedSourcePath;
    String? embedTokSourcePath;
    if (!embedFound) {
      for (final dir in candidateDirs) {
        final candEmb = File('$dir/$_kEmbedFilename');
        final candEmbTok = File('$dir/$_kEmbedTokFilename');
        if (candEmb.existsSync() &&
            candEmb.lengthSync() >= _kEmbedMinBytes &&
            candEmbTok.existsSync()) {
          embedSourcePath = candEmb.path;
          embedTokSourcePath = candEmbTok.path;
          embedFound = true;
          diagLog.writeln('[AURA-DIAG]   ✓ FOUND embedder source in $dir');
          break;
        }
      }
    }
    if (embedSourcePath != null &&
        embedSourcePath != File(embedPath).absolute.path) {
      _setStep(_Step.prepare);
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _copyFileToPrivatePath(
          embedSourcePath,
          embedPath,
          minBytes: _kEmbedMinBytes,
        );
        if (embedTokSourcePath != null) {
          await _copyFileToPrivatePath(
            embedTokSourcePath,
            embedTokPath,
            minBytes: 1024,
          );
        }
        diagLog.writeln('[AURA-DIAG]   ✓ IMPORTED embedder to private cache');
      } catch (e) {
        debugPrint('Embedder import failed: $e — will download/fallback');
        embedFound = false;
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }

    // ── Scan candidates for tokenizer (import source into app-private)
    bool tokFound =
        File(tokPath).existsSync() && File(tokPath).lengthSync() > 1024;
    if (tokFound) {
      diagLog.writeln('[AURA-DIAG]   ✓ USING private tokenizer cache');
    }
    for (final dir in candidateDirs) {
      if (tokFound) break;
      final candTok = File('$dir/$_kTokenizerFilename');
      if (candTok.existsSync() && candTok.lengthSync() > 1024) {
        tokFound = true;
        diagLog.writeln('[AURA-DIAG]   ✓ FOUND tokenizer source in $dir');
        break;
      }
    }

    diagLog.writeln(
      '[AURA-DIAG] final modelPath=$modelPath modelFound=$modelFound',
    );
    diagLog.writeln(
      '[AURA-DIAG] final embedPath=$embedPath embedFound=$embedFound',
    );
    diagLog.writeln('[AURA-DIAG] final tokPath=$tokPath tokFound=$tokFound');

    // Flush all diagnostics to logcat
    for (final line in diagLog.toString().split('\n')) {
      if (line.isNotEmpty) debugPrint(line);
    }

    // ── Deduplicate model files across candidate dirs ────────────────
    // The same multi-hundred-MB GGUF / ONNX was being kept in BOTH
    // app_flutter (internal) AND the external Android/data dir —
    // identical bytes stored twice ≈ 2 GB install footprint. Now that a
    // canonical path has been chosen for each asset, delete every other
    // app-owned copy. Shared Downloads is import-only and must not be
    // treated as cleanup territory.
    final cleanupDirs = candidateDirs
        .where(
          (dir) =>
              dir != '/sdcard/Download' &&
              dir != '/storage/emulated/0/Download',
        )
        .toList();
    if (modelFound) {
      await _dedupeModelFile(_kModelFilename, modelPath, cleanupDirs);
      await _removeStaleModelFiles(cleanupDirs, modelPath);
    }
    if (embedFound) {
      await _dedupeModelFile(_kEmbedFilename, embedPath, cleanupDirs);
      await _dedupeModelFile(_kEmbedTokFilename, embedTokPath, cleanupDirs);
    }

    // Tokenizer: copy from bundled assets if not found on disk.
    if (!tokFound) {
      try {
        await _copyAssetToFile(_kTokenizerAssetPath, tokPath);
      } catch (e) {
        _setError('Tokenizer copy failed:\n$e');
        _loadingLock = false;
        return null;
      }
    }

    // Download the GGUF model ONLY if not found via push or prior dl.
    if (!modelFound) {
      _setStep(_Step.download);
      _updateState(() => _downloadProgress = 0.0);
      try {
        await _download(_kModelUrl, modelPath);
      } catch (e) {
        if (File(modelPath).existsSync()) await File(modelPath).delete();
        // Show diagnostics ON SCREEN so failures are debuggable without
        // logcat. The diagLog contains every dir checked + file listing.
        // Show the FULL set of working push targets, because external
        // storage is read-only on some devices (e.g. Samsung A16: errno
        // 30 on /storage/emulated, /sdcard absent). The app's private
        // internal dir always works via `run-as` on debuggable builds.
        final pushTarget =
            externalDir ??
            '/storage/emulated/0/Android/data/com.example.aura_notebook/files';
        final hint =
            'Model not found. Push it via adb. If the first '
            'command fails ("read-only" or "no such file"), use the '
            'run-as method below — it targets the app private dir which '
            'always works:\n\n'
            'Option A (external dir — may be read-only):\n'
            '  adb push $_kModelFilename $pushTarget/\n\n'
            'Option B (app private dir — always works, debug builds):\n'
            '  adb push $_kModelFilename /data/local/tmp/$_kModelFilename\n'
            '  adb shell run-as com.example.aura_notebook cp /data/local/tmp/$_kModelFilename $appDocsDir/$_kModelFilename\n'
            '  adb shell rm /data/local/tmp/$_kModelFilename\n\n'
            'Then press "Try again".';
        _setError(
          'Model not found.\n$hint\n\nDownload also failed:\n$e\n\n--- Diagnostics ---\n${diagLog.toString()}',
        );
        _loadingLock = false;
        return null;
      } finally {
        _updateState(() => _downloadProgress = null);
      }
      if (!await _validateChatModelPath(modelPath, cleanupDirs)) {
        _setError(
          'Downloaded model is not the expected chat model ($_kModelFilename).',
        );
        _loadingLock = false;
        return null;
      }
    }

    // Download the embedder ONLY if not found via push or prior dl.
    if (_kEmbedModelUrl.isNotEmpty && !embedFound) {
      _updateState(() => _downloadProgress = 0.0);
      _setStep(_Step.download);
      try {
        await _download(_kEmbedModelUrl, embedPath);
        if (!File(embedTokPath).existsSync()) {
          await _download(_kEmbedTokUrl, embedTokPath);
        }
      } catch (e) {
        debugPrint('Embedder download failed: $e — continuing without');
      } finally {
        _updateState(() => _downloadProgress = null);
      }
    }

    return (
      modelPath: modelPath,
      tokPath: tokPath,
      embedPath: embedPath,
      embedTokPath: embedTokPath,
    );
  }
}
