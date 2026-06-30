part of 'tts_service.dart';

// ── AuraTTSService online mixin (configured online TTS + Google Translate) ───
extension _AuraTTSServiceOnline on AuraTTSService {
  Future<Uint8List?> _synthesizeConfiguredOnlineTTS(String text) async {
    final endpoint = Platform.environment['AURA_ONLINE_TTS_URL']?.trim();
    if (endpoint == null || endpoint.isEmpty) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 4));
      request.headers.contentType = ContentType.text;
      request.write(text);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final bytes = await consolidateHttpClientResponseBytes(response);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          bytes.isNotEmpty) {
        _lastProvider = 'configured_online_tts';
        debugPrint('AuraTTS: configured free online TTS succeeded');
        return bytes;
      }
      debugPrint(
        'AuraTTS: configured free online TTS failed: HTTP ${response.statusCode}, bytes=${bytes.length}',
      );
      _onlineBackoffUntil = DateTime.now().add(const Duration(seconds: 30));
      return null;
    } catch (e) {
      debugPrint('AuraTTS: configured free online TTS failed or timed out: $e');
      _onlineBackoffUntil = DateTime.now().add(const Duration(seconds: 30));
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List?> _synthesizeGoogleTranslateTTS(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final phrase = trimmed.runes.length > 180
        ? String.fromCharCodes(trimmed.runes.take(180))
        : trimmed;

    const kClients = ['gtx', 'tw-ob', 't'];
    for (final clientId in kClients) {
      final url = Uri.https('translate.google.com', '/translate_tts', {
        'ie': 'UTF-8',
        'client': clientId,
        'tl': 'en',
        'q': phrase,
      });
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 4);
      try {
        final request = await httpClient
            .getUrl(url)
            .timeout(const Duration(seconds: 4));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        );
        request.headers.set('Referer', 'https://translate.google.com/');
        request.headers.set('Accept-Language', 'en-US,en;q=0.9');
        final response = await request.close().timeout(
          const Duration(seconds: 6),
        );
        final bytes = await consolidateHttpClientResponseBytes(response);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            bytes.isNotEmpty) {
          _lastProvider = 'google_translate_tts';
          debugPrint(
            'AuraTTS: Google Translate TTS succeeded (client=$clientId)',
          );
          return bytes;
        }
        debugPrint(
          'AuraTTS: Google TTS client=$clientId → HTTP ${response.statusCode}',
        );
      } catch (e) {
        debugPrint('AuraTTS: Google TTS client=$clientId error: $e');
      } finally {
        httpClient.close(force: true);
      }
    }
    _onlineBackoffUntil = DateTime.now().add(const Duration(seconds: 15));
    debugPrint('AuraTTS: all Google TTS clients failed — backing off 15s');
    return null;
  }

  Future<bool> _speakGoogleTranslate(
    String text,
    bool interrupt,
    VoidCallback? onComplete,
  ) async {
    final bytes = await _synthesizeGoogleTranslateTTS(text);
    if (bytes == null || bytes.isEmpty) return false;
    return _playOnlineBytes(
      bytes,
      'aura_google_tts.mp3',
      interrupt,
      onComplete,
    );
  }

  Future<bool> _speakConfiguredOnline(
    String text,
    bool interrupt,
    VoidCallback? onComplete,
  ) async {
    final bytes = await _synthesizeConfiguredOnlineTTS(text);
    if (bytes == null || bytes.isEmpty) return false;
    return _playOnlineBytes(
      bytes,
      'aura_online_tts_audio',
      interrupt,
      onComplete,
    );
  }

  Future<bool> _playOnlineBytes(
    Uint8List bytes,
    String fileName,
    bool interrupt,
    VoidCallback? onComplete,
  ) async {
    if (interrupt) {
      await stop();
    }
    _isPlaying = true;
    _isPlayingOnline = true;

    final player = _getOnlinePlayer;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      StreamSubscription? sub;
      sub = player.onPlayerComplete.listen((_) async {
        _isPlaying = false;
        _isPlayingOnline = false;
        await sub?.cancel();
        onComplete?.call();
      });

      await player.setVolume(_muted ? 0.0 : _volume);
      await player.play(DeviceFileSource(file.path));
      return true;
    } catch (e) {
      debugPrint(
        'AuraTTS: online playback error: $e. Falling back to offline TTS...',
      );
      _isPlayingOnline = false;
      return false;
    }
  }
}
