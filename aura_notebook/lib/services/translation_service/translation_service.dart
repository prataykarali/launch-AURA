import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'translation_result.dart';
import 'transliteration.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const Duration _timeout = Duration(seconds: 3);
  static const int _maxCacheEntries = 32;

  final Map<String, TranslationResult> _cache = {};

  Future<TranslationResult> toEnglish(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult(
        original: text,
        english: text,
        changed: false,
        source: 'empty',
      );
    }
    if (trimmed.startsWith('/')) {
      return TranslationResult(
        original: text,
        english: trimmed,
        changed: false,
        source: 'command',
      );
    }
    final cached = _cache[trimmed];
    if (cached != null) return cached;

    final online = await _translateOnline(trimmed);
    if (online != null && online.trim().isNotEmpty) {
      final translated = online.trim();
      debugPrint('[AURA TRANSLATION] online "$trimmed" -> "$translated"');
      return _remember(
        trimmed,
        TranslationResult(
          original: text,
          english: translated,
          changed: translated != trimmed,
          source: 'google_translate',
        ),
      );
    }

    if (!Transliteration.looksNonEnglish(trimmed)) {
      return _remember(
        trimmed,
        TranslationResult(
          original: text,
          english: trimmed,
          changed: false,
          source: 'offline_passthrough',
        ),
      );
    }

    final fallback = Transliteration.offlineFallback(trimmed);
    if (fallback != trimmed) {
      debugPrint(
        '[AURA TRANSLATION] offline fallback "$trimmed" -> "$fallback"',
      );
      return _remember(
        trimmed,
        TranslationResult(
          original: text,
          english: fallback,
          changed: true,
          source: 'offline_transliteration',
        ),
      );
    }

    debugPrint('[AURA TRANSLATION] no translation available; passing raw text');
    return _remember(
      trimmed,
      TranslationResult(
        original: text,
        english: trimmed,
        changed: false,
        source: 'offline_passthrough',
      ),
    );
  }

  TranslationResult _remember(String key, TranslationResult result) {
    _cache[key] = result;
    if (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return result;
  }

  Future<String?> _translateOnline(String text) async {
    HttpClient? client;
    try {
      final url = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': 'auto',
        'tl': 'en',
        'dt': 't',
        'q': text,
      });
      client = HttpClient()..connectionTimeout = _timeout;
      final request = await client.getUrl(url).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! List || decoded.isEmpty || decoded[0] is! List) {
        return null;
      }
      final buffer = StringBuffer();
      for (final part in decoded[0] as List) {
        if (part is List && part.isNotEmpty && part[0] is String) {
          buffer.write(part[0] as String);
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('[AURA TRANSLATION] online failed: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
