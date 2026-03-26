import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PathManager {
  static Future<String> getModelPath() async {
    // 1. Check for Android
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory(); // Usually /storage/emulated/0/Android/data/...
      return "${dir!.path}/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
    }

    // 2. Check for Linux/Windows/macOS (Desktop)
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // While developing, you can use your hardcoded path
      // But for a REAL launch, you'd use the user's document folder:
      // final dir = await getApplicationSupportDirectory();
      // return "${dir.path}/models/model.gguf";

      return "/home/pratay-karali/AURA-Proj/candle_LNN/aura_lnn/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
    }

    throw UnsupportedError("This platform is not supported yet!");
  }

  static Future<String> getTokenizerPath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      return "${dir!.path}/Q4_K_M.json";
    }
    return "/home/pratay-karali/AURA-Proj/candle_LNN/aura_lnn/models/Q4_K_M.json";
  }
}