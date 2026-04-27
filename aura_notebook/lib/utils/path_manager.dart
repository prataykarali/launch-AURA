import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _kModelFile     = 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerFile = 'tokenizer.json';

class PathManager {
  static String get _internalBase {
    if (Platform.isLinux) {
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

  static Future<String> getModelsDir() async {
    if (Platform.isAndroid) {
      // getExternalStorageDirectory() → /sdcard/Android/data/<pkg>/files/
      // App owns this dir — no permission required on Android 14
      final extDir = await getExternalStorageDirectory();
      final dir = Directory('${extDir!.path}/models');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir.path;
    }
    final dir = Directory('$_internalBase/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Future<String> getModelPath() async =>
      '${await getModelsDir()}/$_kModelFile';

  static Future<String> getTokenizerPath() async =>
      '${await getModelsDir()}/$_kTokenizerFile';

  static Future<bool> modelExists() async {
    final mFile = File(await getModelPath());
    final tFile = File(await getTokenizerPath());
    return mFile.existsSync() && mFile.lengthSync() > 0 &&
        tFile.existsSync() && tFile.lengthSync() > 0;
  }
}