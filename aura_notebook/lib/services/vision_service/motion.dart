part of 'vision_service.dart';

// ── Motion detection ──────────────────────────────────────────────────────
//
// Computes a 16-bucket luminance histogram of the JPEG thumbnail and
// computes L1 distance with the previous frame histogram.
// Very fast — no ML, no native calls.

bool _detectMotion(VisionService service, Uint8List frame) {
  if (service._prevFrame == null) return true; // first frame always counts as motion

  final curr = _lumaHistogram(frame);
  final prev = _lumaHistogram(service._prevFrame!);

  double diff = 0;
  for (int i = 0; i < curr.length; i++) {
    diff += (curr[i] - prev[i]).abs();
  }

  return diff > VisionService._kMotionThreshold;
}

// Crude luminance histogram from raw bytes: sample every ~16th byte
// and bucket into 16 bins. Good enough for motion gating.
List<double> _lumaHistogram(Uint8List bytes) {
  final buckets = List<double>.filled(16, 0);
  int count = 0;
  for (int i = 0; i < bytes.length; i += 16) {
    final v = bytes[i];
    buckets[v >> 4] += 1;
    count++;
  }
  if (count == 0) return buckets;
  for (int i = 0; i < 16; i++) {
    buckets[i] /= count;
  }
  return buckets;
}

double _averageLuma(Uint8List bytes) {
  if (bytes.isEmpty) return 128;
  int sum = 0;
  int samples = 0;
  for (int i = 0; i < bytes.length; i += 32) {
    sum += bytes[i];
    samples++;
  }
  return samples == 0 ? 128 : sum / samples;
}
