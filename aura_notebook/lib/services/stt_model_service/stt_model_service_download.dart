part of 'stt_model_service.dart';

extension _SttModelServiceDownload on SttModelService {
  /// Download one file with HTTP Range resume + retry, writing to `<dest>.part`
  /// then atomically renaming on success. Mirrors loading_screen.dart::_download
  /// so a dropped connection mid-41MB-encoder recovers from where it left off
  /// instead of restarting. [minBytes] validates the result so a truncated file
  /// is rejected (the caller then re-downloads on the next attempt).
  Future<void> _downloadFile(String url, String dest, int minBytes) async {
    await File(dest).parent.create(recursive: true);
    final partFile = File('$dest.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    int attempt = 0;
    const maxAttempts = 5;

    try {
      while (attempt < maxAttempts) {
        attempt++;
        try {
          final startBytes =
              partFile.existsSync() ? partFile.lengthSync() : 0;
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
              throw Exception('Range not satisfiable, resetting');
            }
            throw Exception('HTTP ${response.statusCode} for $url');
          }

          final contentLen = response.contentLength;
          final sink = partFile.openWrite(
              mode: isResume ? FileMode.append : FileMode.write);
          try {
            await for (final chunk in response) {
              sink.add(chunk);
            }
            await sink.flush();
          } finally {
            await sink.close();
          }

          final got = partFile.lengthSync();
          final complete = contentLen < 0 || got >= startBytes + contentLen;
          if (complete) break;
          throw Exception(
              'Incomplete: have $got bytes (+$contentLen from offset $startBytes)');
        } catch (e) {
          debugPrint('SttModelService: attempt $attempt for '
              '${url.split('/').last} failed: $e');
          if (attempt >= maxAttempts) rethrow;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    } finally {
      client.close(force: true);
    }

    if (!partFile.existsSync() || partFile.lengthSync() < minBytes) {
      throw Exception('${dest.split('/').last} too small after download '
          '(${partFile.lengthSync()} < $minBytes)');
    }
    final destFile = File(dest);
    if (destFile.existsSync()) await destFile.delete();
    await partFile.rename(dest);
  }
}
