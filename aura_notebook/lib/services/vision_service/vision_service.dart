import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../bounded_work_bucket.dart';
import '../resource_guard_service.dart';
import '../../src/rust/api/vision.dart';
import '../../src/rust/vision/events.dart';

part 'models.dart';
part 'constants.dart';
part 'profile.dart';
part 'capture.dart';
part 'linux_capture.dart';
part 'android_capture.dart';
part 'context_capture.dart';
part 'ocr_stuck.dart';
part 'motion.dart';
part 'analysis.dart';
part 'pipeline.dart';

// ── VisionService ────────────────────────────────────────────────────────────
//
// Asynchronous, motion-gated vision pipeline.
//
// Design:
//  • Runs in a background Dart isolate-friendly timer — never blocks the chat.
//  • Android is currently disabled by design: opening CameraX/ML Kit while the
//    local LLM is loading or decoding causes visible jank on mid-range phones.
//    Keep mobile vision off until it is moved to a native low-priority worker.
//  • On Linux/Desktop: uses screenshot capture via process (scrot / import).
//  • Motion gate: compares consecutive frame luminance histograms. Skips
//    ~80 % of frames when the scene is static.
//  • Sends `VisionDetection` batches to Rust via `auraProcessVision()`.
//    Rust's VisionGate applies confidence / cooldown / importance filters.
//
// Battery budget:
//  • Polling interval: 4 s (idle) / 2 s (active motion streak).
//  • Motion threshold: luminance diff > 8.0 / 256 (≈ 3 %).
//  • Max active detections per batch: 4 labels.
//
// ─────────────────────────────────────────────────────────────────────────────

class VisionService {
  VisionService._();
  static final VisionService instance = VisionService._();
  static const MethodChannel _androidVisionChannel = MethodChannel(
    'aura/vision_context',
  );

  // ── Detection callback ────────────────────────────────────────────────────
  // Called each time a non-empty detection batch is sent to Rust.
  // AuraBarBrain subscribes to this as a quiet sensory context stream.
  void Function(List<String> labels, double confidence)? onDetectionSent;
  void Function(AuraVisionContext context)? onStructuredContext;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _running = false;
  bool _healthPaused = false;
  Timer? _pollTimer;
  Timer? _healthResumeTimer;
  Uint8List? _prevFrame;
  String? _lastActiveWindow;
  AuraVisionContext? _latestContext;
  String? _lastOcrHash;
  int _sameOcrHashCount = 0;
  bool _stuckEpisodeFired = false;
  bool _usageAccessRequested = false;
  DateTime? _stuckStartedAt;
  DateTime? _lastStuckOcrAt;
  int _motionStreak = 0;
  final List<VisionDetection> _lastAndroidDetections = const [];
  final BoundedWorkBucket<Uint8List> _frameBucket =
      BoundedWorkBucket<Uint8List>(name: 'vision_frames', capacity: 2);

  // Poll intervals
  static const Duration _kIdleInterval = Duration(seconds: 4);
  static const Duration _kActiveInterval = Duration(seconds: 2);

  // Motion gate: luminance bucket diff threshold (0–255 scale)
  static const double _kMotionThreshold = 8.0;

  bool get isRunning => _running && !_healthPaused;
  AuraVisionContext? get latestContext => _latestContext;

  AuraVisionDeviceProfile get deviceProfile => _deviceProfile();

  static const List<String> triggerVocabulary = _visionTriggerVocabulary;

  bool shouldTriggerCapture(String text) => _shouldTriggerCapture(text);

  Future<void> captureNow({String reason = 'explicit'}) =>
      _captureNow(this, reason: reason);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start the passive context loop. Safe to call multiple times.
  /// Linux samples screen context. Android vision is intentionally disabled for
  /// now so camera/ML Kit cannot compete with LLM, overlay, STT or TTS.
  void start() {
    if (_running) return;
    final profile = deviceProfile;
    if (profile == AuraVisionDeviceProfile.mobileMinimal) {
      debugPrint('[Vision] mobile_minimal: listen-only, passive vision off');
      return;
    }
    _running = true;
    _healthPaused = false;
    debugPrint(
      '[Vision] passive context service started profile=${profile.name}',
    );
    _scheduleNext(_kIdleInterval);
  }

  /// Stop the background vision loop.
  void stop() {
    _running = false;
    _healthPaused = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _healthResumeTimer?.cancel();
    _healthResumeTimer = null;
    _frameBucket.clear();
    _prevFrame = null;
    _lastActiveWindow = null;
    _latestContext = null;
    _lastOcrHash = null;
    _sameOcrHashCount = 0;
    _stuckEpisodeFired = false;
    _usageAccessRequested = false;
    _stuckStartedAt = null;
    _motionStreak = 0;
    debugPrint('[Vision] service stopped');
  }

  void pauseForHealth(Duration duration) {
    if (!_running) return;
    _healthPaused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _frameBucket.clear();
    _healthResumeTimer?.cancel();
    _healthResumeTimer = Timer(duration, () {
      _healthPaused = false;
      if (_running) {
        debugPrint('[Vision] health pause ended — resuming');
        _scheduleNext(_kIdleInterval);
      }
    });
    debugPrint('[Vision] paused for health guard (${duration.inSeconds}s)');
  }

  // ── Internal poll loop ────────────────────────────────────────────────────

  void _scheduleNext(Duration interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer(interval, _poll);
  }

  Future<void> _poll() => _pollImpl(this);

  Future<void> _processFrame(Uint8List frame) =>
      _processFrameImpl(this, frame);

  bool consumeStuckEpisodeTrigger() => _consumeStuckEpisodeTrigger(this);
}
