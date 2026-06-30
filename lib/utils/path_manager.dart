import 'dart:io';

const _kModelFile = 'LFM2.5-230M-Q8_0.gguf';
const _kTokenizerFile = 'tokenizer.json';

class PathManager {
  // Internal app data dir — always accessible, no permissions, no plugins
  static const _internalBase = '/data/data/com.example.aura_notebook/files';
  static const _sdcardBase =
      '/sdcard/Android/data/com.example.aura_notebook/files/models';

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
    return mFile.existsSync() &&
        mFile.lengthSync() > 0 &&
        tFile.existsSync() &&
        tFile.lengthSync() > 0;
  }
}
