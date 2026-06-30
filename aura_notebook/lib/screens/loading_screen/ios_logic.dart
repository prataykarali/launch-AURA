part of 'main.dart';

extension _LoadingScreenIosLogic on _LoadingScreenState {
  Future<_ModelPaths?> _loadIos({
    required String appDocsDir,
    required bool requireEmbed,
  }) async {
    // On iOS, use the existing models dir approach.
    final dir = await PathManager.getModelsDir();
    await Directory(dir).create(recursive: true);
    final modelPath = '$dir/$_kModelFilename';
    final tokPath = '$dir/$_kTokenizerFilename';
    final embedPath = '$dir/$_kEmbedFilename';
    final embedTokPath = '$dir/$_kEmbedTokFilename';

    try {
      await _ensureFiles(
        modelPath: modelPath,
        tokPath: tokPath,
        embedPath: embedPath,
        embedTokPath: embedTokPath,
        requireEmbed: requireEmbed,
      );
    } catch (e) {
      _setError('File prepare failed:\n$e');
      _loadingLock = false;
      return null;
    }
    if (!await _validateChatModelPath(modelPath, [dir, appDocsDir])) {
      _setError(
        'Chat model not found. Expected $_kModelFilename, but startup resolved:\n$modelPath',
      );
      _loadingLock = false;
      return null;
    }

    return (
      modelPath: modelPath,
      tokPath: tokPath,
      embedPath: embedPath,
      embedTokPath: embedTokPath,
    );
  }
}
