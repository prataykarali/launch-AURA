import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Microsoft Edge Neural TTS client using the official Edge ReadAloud WebSocket API.
/// Zero external binary dependencies, cross-platform (Linux, Windows, macOS, Android).
class EdgeTTSClient {
  static const String _kEndpoint =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const String _kTrustedToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';

  /// Default high-quality neural voice. Options:
  /// - 'en-US-AriaNeural' (Warm, expressive, natural)
  /// - 'en-US-AvaNeural' (Modern, conversational)
  /// - 'en-US-JennyNeural' (Friendly, crisp)
  /// - 'en-US-GuyNeural' (Natural male voice)
  static const String defaultVoice = 'en-US-AriaNeural';

  /// Synthesize text to MP3 audio bytes using Microsoft Edge TTS.
  /// Returns null if offline, timed out, or if connection failed.
  static Future<Uint8List?> synthesize({
    required String text,
    String voice = defaultVoice,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final connectionId = _generateId();
    final requestId = _generateId();
    final url =
        '$_kEndpoint?TrustedClientToken=$_kTrustedToken&ConnectionId=$connectionId';

    WebSocket? socket;
    try {
      final customHeaders = {
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'Accept-Encoding': 'gzip, deflate, br',
        'Accept-Language': 'en-US,en;q=0.9',
      };

      socket = await WebSocket.connect(
        url,
        headers: customHeaders,
      ).timeout(const Duration(seconds: 3));

      final completer = Completer<Uint8List?>();
      final audioBuffer = BytesBuilder(copy: false);

      // 1. Send speech.config
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final configPayload = jsonEncode({
        'context': {
          'synthesis': {
            'audio': {
              'metadataoptions': {
                'sentenceBoundaryEnabled': 'false',
                'wordBoundaryEnabled': 'false',
              },
              'outputFormat': 'audio-24khz-48kbitrate-mono-mp3',
            }
          }
        }
      });

      final configMessage =
          'Content-Type:application/json; charset=utf-8\r\n'
          'Path:speech.config\r\n\r\n'
          '$configPayload';
      socket.add(configMessage);

      // 2. Send SSML request
      final escapedText = _escapeXml(trimmed);
      final ssml =
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>"
          "<voice name='$voice'>"
          "<prosody pitch='+0Hz' rate='+0%' volume='+0%'>"
          "$escapedText"
          "</prosody></voice></speak>";

      final ssmlMessage =
          'X-RequestId:$requestId\r\n'
          'Content-Type:application/ssml+xml\r\n'
          'X-Timestamp:${timestamp}Z\r\n'
          'Path:ssml\r\n\r\n'
          '$ssml';
      socket.add(ssmlMessage);

      // 3. Listen for audio chunks
      socket.listen(
        (data) {
          if (data is String) {
            if (data.contains('Path:turn.end')) {
              if (!completer.isCompleted) {
                final result = audioBuffer.toBytes();
                completer.complete(result.isNotEmpty ? result : null);
              }
            }
          } else if (data is List<int>) {
            // Binary message parsing
            if (data.length > 2) {
              final headerLen = (data[0] << 8) | data[1];
              if (data.length > 2 + headerLen) {
                final audioData = data.sublist(2 + headerLen);
                if (audioData.isNotEmpty) {
                  audioBuffer.add(audioData);
                }
              }
            }
          }
        },
        onError: (err) {
          debugPrint('EdgeTTS WebSocket error: $err');
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) {
            final result = audioBuffer.toBytes();
            completer.complete(result.isNotEmpty ? result : null);
          }
        },
        cancelOnError: true,
      );

      final bytes = await completer.future.timeout(timeout, onTimeout: () {
        debugPrint('EdgeTTS synthesis timed out after ${timeout.inSeconds}s');
        return null;
      });

      return bytes;
    } catch (e) {
      debugPrint('EdgeTTS connection/synthesis failed: $e');
      return null;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final random = (DateTime.now().millisecondsSinceEpoch * 31 % 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return '$now$random';
  }
}
