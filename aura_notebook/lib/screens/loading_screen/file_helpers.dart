part of 'main.dart';

/// Check available disk space on the path's filesystem (Linux/Android only).
/// Returns null on unsupported platforms or on error.
Future<int?> _getAvailableDiskSpace(String path) async {
  if (!Platform.isLinux && !Platform.isAndroid) return null;
  try {
    final result = await Process.run('df', ['-B1', '--output=avail', path]);
    if (result.exitCode != 0) return null;
    final lines = (result.stdout as String).split('\n');
    if (lines.length < 2) return null;
    final availStr = lines[1].trim();
    return int.tryParse(availStr);
  } catch (_) {
    return null;
  }
}

String _formatBytes(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes >= gib) return '${(bytes / gib).toStringAsFixed(2)} GiB';
  return '${(bytes / mib).toStringAsFixed(0)} MiB';
}

/// Build a storage hint string for error messages. Shows how much space is
/// available and how much needs to be freed for AURA to load.
Future<String> _storageHint(String path) async {
  final avail = await _getAvailableDiskSpace(path);
  if (avail == null) return '';
  final needed = _kTotalNeededBytes;
  if (avail >= needed) {
    return '\nAvailable: ${_formatBytes(avail)} — enough for AURA.';
  }
  final toFree = needed - avail;
  return '\nAvailable: ${_formatBytes(avail)}'
      '\nAURA needs: ${_formatBytes(needed)}'
      '\nFree up ${_formatBytes(toFree)} to reload AURA.';
}

// On Linux/Windows/macOS, use model directly from the asset bundle / source
// dir to avoid a multi-hundred-MB memory copy.
bool get _kUseAssetDirectly =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Resolve the GGUF model path on desktop by walking the same candidate set
/// the rest of the app uses for bundled assets: the built bundle's flutter
/// assets, the cwd-relative assets, ancestors of both, and the absolute source
/// fallback. Returns the first candidate whose file is at least
/// [_kModelMinBytes], else null (caller will then have to download — desktop
/// dev convenience). Mirrors AuraTTSService._ancestorAssetDirs / _probePiperCli.
Future<String?> _resolveDesktopModelPath(String assetBase) async {
  return _resolveDesktopFile(_kModelFilename, assetBase, _kModelMinBytes);
}

/// Generic desktop file resolver. Checks bundle, cwd, ancestor dirs, and the
/// absolute source fallback. Returns the first candidate path whose file
/// exists and is at least [minBytes], else null.
Future<String?> _resolveDesktopFile(
  String filename,
  String assetBase,
  int minBytes,
) async {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final cwd = Directory.current.path;
  final candidates = <String>[
    '$assetBase/$filename',
    '$exeDir/data/flutter_assets/assets/$filename',
    '$cwd/assets/$filename',
    ..._ancestorCandidatesFor(exeDir, filename),
    ..._ancestorCandidatesFor(cwd, filename),
  ];
  final home = Platform.environment['HOME'];
  if (home != null) {
    candidates.add(
      '$home/launch-AURA/AURA-Proj/aura_notebook/assets/$filename',
    );
  }
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync() && f.lengthSync() >= minBytes) return c;
  }
  return null;
}

/// Walk up from [start] returning each existing `<ancestor>/assets/<filename>`,
/// nearest first. Mirrors AuraTTSService._ancestorAssetDirs.
List<String> _ancestorCandidatesFor(String start, String filename) {
  final out = <String>[];
  var dir = Directory(start);
  if (!dir.isAbsolute) return out;
  for (var i = 0; i < 12 && dir.parent.path != dir.path; i++) {
    final cand = Directory('${dir.path}/assets');
    if (cand.existsSync()) out.add('${cand.path}/$filename');
    dir = dir.parent;
  }
  return out;
}

bool _isExpectedChatModel(String path) {
  final file = File(path);
  return path.endsWith('/$_kModelFilename') &&
      file.existsSync() &&
      file.lengthSync() >= _kModelMinBytes;
}

Future<void> _removeStaleModelFiles(
  List<String> dirs,
  String canonicalPath,
) async {
  final keep = File(canonicalPath).absolute.path;
  final seen = <String>{};
  for (final dir in dirs) {
    if (dir.isEmpty || !seen.add(dir)) continue;
    final root = Directory(dir);
    if (!root.existsSync()) continue;

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final isModel =
          name.endsWith('.gguf') ||
          _kOldModelSuffixes.any((suffix) => name.endsWith(suffix));
      if (!isModel || entity.absolute.path == keep) continue;
      try {
        await entity.delete();
        debugPrint('[AURA-MODEL] removed stale model cache: ${entity.path}');
      } catch (e) {
        debugPrint(
          '[AURA-MODEL] could not remove stale model cache ${entity.path}: $e',
        );
      }
    }
  }
}

/// Delete duplicate copies of a model file in every [dirs] entry EXCEPT
/// [canonicalPath]. On Android the same multi-hundred-MB GGUF / ONNX file was
/// accumulating in BOTH the app's private dir (app_flutter) and the external
/// app dir (Android/data/.../files) — identical bytes (verified by md5) but
/// stored twice, which is the source of the ~2 GB reported install size.
///
/// This runs AFTER a canonical path has been chosen, so we never delete the
/// copy the engine is actually going to load. Best-effort and silent on
/// failure: a delete failing (read-only external dir, permissions) just means
/// that duplicate survives this launch — it is retried next launch.
Future<void> _dedupeModelFile(
  String filename,
  String canonicalPath,
  List<String> dirs,
) async {
  final canonical = File(canonicalPath);
  // Only dedupe if the canonical copy is actually present and valid, so we
  // never wipe a file that the caller still needs to download/create.
  if (!canonical.existsSync()) return;
  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    final dup = File('$dir/$filename');
    if (!dup.existsSync()) continue;
    // Don't touch the canonical file itself (compare absolute paths).
    final dupAbs = dup.absolute.path;
    final canAbs = canonical.absolute.path;
    if (dupAbs == canAbs) continue;
    try {
      await dup.delete();
      debugPrint(
        '[AURA-DEDUP] removed duplicate $filename from $dir '
        '(canonical kept at $canonicalPath)',
      );
    } catch (e) {
      // Common on Samsung: external storage is read-only (errno 30). The
      // duplicate survives; we'll try again next launch. Not fatal.
      debugPrint('[AURA-DEDUP] could not delete $filename from $dir: $e');
    }
  }
}
