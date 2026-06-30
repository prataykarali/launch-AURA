import 'transliteration_maps_north.dart';
import 'transliteration_maps_south.dart';

class Transliteration {
  Transliteration._();

  static bool looksNonEnglish(String text) {
    final letters = text.runes.where(_isLetter).toList(growable: false);
    if (letters.isEmpty) return false;
    final asciiLetters = letters.where((r) {
      final lower = r | 0x20;
      return lower >= 0x61 && lower <= 0x7a;
    }).length;
    if (asciiLetters == letters.length) return false;
    return asciiLetters / letters.length < 0.85;
  }

  static bool _isLetter(int r) {
    final lower = r | 0x20;
    if (lower >= 0x61 && lower <= 0x7a) return true;
    if (r >= 0x00C0 && r <= 0x02AF) return true;
    if (r >= 0x0370 && r <= 0x1FFF) return true;
    if (r >= 0x2C00 && r <= 0xD7FF) return true;
    return false;
  }

  static String offlineFallback(String text) {
    final buffer = StringBuffer();
    var changed = false;
    for (final r in text.runes) {
      final mapped = _transliterateRune(r);
      if (mapped != null) {
        buffer.write(mapped);
        changed = true;
      } else {
        buffer.writeCharCode(r);
      }
    }
    return changed
        ? buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim()
        : text;
  }

  static String? _transliterateRune(int r) {
    if (r >= 0x0900 && r <= 0x097F) return devanagari[r];
    if (r >= 0x0980 && r <= 0x09FF) return bengali[r];
    if (r >= 0x0A80 && r <= 0x0AFF) return gujarati[r];
    if (r >= 0x0B80 && r <= 0x0BFF) return tamil[r];
    if (r >= 0x0C00 && r <= 0x0C7F) return telugu[r];
    if (r >= 0x0C80 && r <= 0x0CFF) return kannada[r];
    if (r >= 0x0D00 && r <= 0x0D7F) return malayalam[r];
    return null;
  }
}
