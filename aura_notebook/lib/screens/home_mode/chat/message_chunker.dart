// message_chunker.dart
// Splits a long user message into sequential chunks for auraChatChunked().
//
// Strategy:
//   1. Paragraph boundaries (\n\n) first — natural break points
//   2. Sentence boundaries (.!?) within long paragraphs
//   3. Hard word-boundary cap at ~400 chars as final fallback
//
// Returns a single-element list if the message is short enough.
// ─────────────────────────────────────────────────────────────────────────────

import 'chat_constants.dart';

List<String> chunkMessage(String text) {
  final paragraphs = text
      .split(RegExp(r'\n\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  final chunks = <String>[];

  for (final para in paragraphs) {
    if (para.length <= kChunkThreshold) {
      chunks.add(para);
      continue;
    }

    // Sentence split within long paragraph
    final sentences = para.split(RegExp(r'(?<=[.!?])\s+'));
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      final candidate = buffer.isEmpty
          ? sentence
          : '${buffer.toString()} $sentence';

      if (candidate.length > kChunkThreshold && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer = StringBuffer(sentence);
      } else {
        buffer.clear();
        buffer.write(candidate);
      }
    }

    if (buffer.isNotEmpty) {
      final remaining = buffer.toString().trim();
      // Hard cap fallback: split on word boundary at ~400 chars
      if (remaining.length > 400) {
        var start = 0;
        while (start < remaining.length) {
          var end = (start + 400).clamp(0, remaining.length);
          if (end < remaining.length) {
            final spaceIdx = remaining.lastIndexOf(' ', end);
            if (spaceIdx > start) end = spaceIdx;
          }
          chunks.add(remaining.substring(start, end).trim());
          start = end;
        }
      } else {
        chunks.add(remaining);
      }
    }
  }

  return chunks.isEmpty ? [text.trim()] : chunks;
}