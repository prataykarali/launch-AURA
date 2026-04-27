import 'dart:io';

const _kModelFile     = 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerFile = 'Q4_K_M.json';

class PathManager {
  // ── Platform-aware base path ──────────────────────────────────────────────
  static String get _internalBase {
    if (Platform.isAndroid) {
      return '/data/data/com.example.aura_notebook/files';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/.local/share/aura_notebook/files';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? 'C:/temp';
      return '$appData/aura_notebook/files';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      return '$home/Library/Application Support/aura_notebook/files';
    }
    return '/tmp/aura_notebook/files';
  }

  static const _sdcardBase =
      '/sdcard/Android/data/com.example.aura_notebook/files/models';

  // ── Methods ───────────────────────────────────────────────────────────────
  static Future<String> getModelsDir() async {
    final dir = Directory('$_internalBase/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Future<String> getModelPath() async =>
      '${await getModelsDir()}/$_kModelFile';

  static Future<String> getTokenizerPath() async =>
      '${await getModelsDir()}/$_kTokenizerFile';

  static String get sdcardModelPath => '$_sdcardBase/$_kModelFile';
  static String get sdcardTokenizerPath => '$_sdcardBase/$_kTokenizerFile';

  static Future<bool> modelExists() async {
    final mFile = File(await getModelPath());
    final tFile = File(await getTokenizerPath());
    return mFile.existsSync() && mFile.lengthSync() > 0 &&
        tFile.existsSync() && tFile.lengthSync() > 0;
  }
}