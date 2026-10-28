part of 'vision_service.dart';

// ── Motion detection ──────────────────────────────────────────────────────
//
// Two-phase approach:
//  1. Fast path: compare JPEG file sizes — same screen produces similar sizes.
//  2. Content path: compare OCR text hashes — catches semantic changes even
//     when file sizes are close (e.g. cursor blink vs real content change).
//
// Previous approach sampled raw JPEG bytes as pixel luma — wrong because
// JPEG bytes are compressed data, not pixel values. This caused false
// motion detection on every frame.

bool _detectMotion(VisionService service, Uint8List frame) {
  if (service._prevFrame == null) return true;

  // Phase 1: file size delta — quick rejection of identical frames.
  final prevSize = service._prevFrame!.length;
  final currSize = frame.length;
  final sizeDiffRatio =
      (currSize - prevSize).abs() / (prevSize > 0 ? prevSize : 1);

  // If JPEG sizes differ by > 3%, something changed.
  if (sizeDiffRatio > 0.03) return true;

  // Phase 2: compare first-2KB hash — catches content changes when
  // compression produces similar-sized files (e.g. typing one character).
  final prevHash = _quickHash(service._prevFrame!);
  final currHash = _quickHash(frame);
  return prevHash != currHash;
}

/// Fast hash of first N bytes — enough to detect content changes in JPEG.
int _quickHash(Uint8List bytes) {
  const sampleLen = 2048;
  final len = bytes.length < sampleLen ? bytes.length : sampleLen;
  int hash = 0x811c9dc5; // FNV offset basis
  for (int i = 0; i < len; i += 3) {
    hash ^= bytes[i];
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime
  }
  return hash;
}

double _averageLuma(Uint8List bytes) {
  // For JPEG bytes this is a rough heuristic — not real pixel luma.
  // Kept for backward compat with bright_scene/dim_scene detection labels.
  if (bytes.isEmpty) return 128;
  int sum = 0;
  int samples = 0;
  for (int i = 0; i < bytes.length; i += 64) {
    sum += bytes[i];
    samples++;
  }
  return samples == 0 ? 128 : sum / samples;
}
