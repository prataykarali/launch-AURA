import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _kModelFile = 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerFile = 'tokenizer.json';

class PathManager {
  static Future<String> getModelsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final models = Directory('${dir.path}/models');
    if (!models.existsSync()) models.createSync(recursive: true);
    return models.path;
  }

  static Future<String> getModelPath() async =>
      '${await getModelsDir()}/$_kModelFile';

  static Future<String> getTokenizerPath() async =>
      '${await getModelsDir()}/$_kTokenizerFile';

  static Future<bool> modelExists() async {
    final mFile = File(await getModelPath());
    final tFile = File(await getTokenizerPath());
    return mFile.existsSync() &&
        mFile.lengthSync() > 0 &&
        tFile.existsSync() &&
        tFile.lengthSync() > 0;
  }
}
