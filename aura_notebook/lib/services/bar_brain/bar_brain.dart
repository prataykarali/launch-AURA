import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

import '../stt_service.dart';
import '../tts_service.dart';
import '../stt_model_service.dart';
import '../vision_service.dart';
import '../resource_guard_service.dart';
import '../natural_context_service.dart';
import '../proactive_scheduler.dart';
import '../../bar/bar_multi_window_service.dart';
import '../../bar/bar_state.dart';
import '../../src/rust/api.dart';

part 'bar_brain_ui.dart';
part 'bar_brain_engine.dart';
part 'bar_brain_vision.dart';
part 'bar_brain_mic.dart';
part 'bar_brain_prompt.dart';
part 'bar_brain_greeting.dart';
part 'bar_brain_proactive.dart';
part 'bar_brain_public.dart';
part 'bar_brain_volume.dart';
part 'bar_brain_wake_word.dart';
part 'bar_brain_generation.dart';

// ── Queued prompt entry ────────────────────────────────────────────────────
class _QueuedPrompt {
  final String text;
  final AuraObservationSource source;
  final DateTime queuedAt;
  _QueuedPrompt(this.text, this.source) : queuedAt = DateTime.now();
}

// ── AuraBarBrain ──────────────────────────────────────────────────────────────
//
// Clean state machine for the AURA bar. Split into part files for readability.
// Public surface unchanged.

class AuraBarBrain {
  AuraBarBrain._();
  static final AuraBarBrain instance = AuraBarBrain._();

  /// Passive wake-word ("Hey AURA") listening. Disabled for now — STT is
  /// push-to-talk only via [handleMicTap]. Flip to `true` (and uncomment the
  /// boot call in main.dart) to re-enable ambient listening. The wake-word
  /// methods below stay compiled so they're ready to revive unchanged.
  static const bool kWakeWordEnabled = false;

  // ── Processing state ───────────────────────────────────────────────────────
  StreamSubscription<String>? _chatSubscription;
  bool _isProcessing = false;
  DateTime? _processingStartedAt;
  static const Duration _kProcessingStaleAfter = Duration(seconds: 30);
  bool get isProcessing => _isProcessing;

  bool get _isProcessingStale =>
      _isProcessing &&
      _processingStartedAt != null &&
      DateTime.now().difference(_processingStartedAt!) > _kProcessingStaleAfter;

  Completer<void>? _processingLock;

  // ── Engine readiness ───────────────────────────────────────────────────────
  bool engineReady = false;
  bool _androidInitInProgress = false;
  final List<_QueuedPrompt> _promptQueue = [];
  static const int _kMaxQueueSize = 20;
  AuraObservationSource _pendingPromptSource = AuraObservationSource.text;
  String _currentResponse = '';
  bool _isProactive = false;
  DateTime lastUserInteraction = DateTime.now();
  bool userIsTyping = false;

  // ── TTS state ──────────────────────────────────────────────────────────────
  // One sentence buffer: split _currentResponse on sentence boundaries and call
  // tts.speak(sentence). Rust's rodio sink queues them natively — no _ttsQueue,
  // no _isTtsPlaying, no _speakChain needed.
  String _sentenceBuffer = '';

  // ── Wake-word ──────────────────────────────────────────────────────────────
  // Wake-word passive-listening state. The loop in _runWakeWordCycle uses these
  // to suppress re-entry and to schedule restart after a busy/bar/cycle window.
  bool _wakeWordEnabled = false;
  bool _isWakeWordListening = false;
  Timer? _wakeWordRestartTimer;

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _maxListenTimer;
  Timer? _silenceTimer; // auto-finalizes STT after ~1.5s of silence
  Timer? _partialTranscriptTimer;
  StreamSubscription<double>? _silenceSub; // watches soundLevelNotifier
  Timer? _responseFadeTimer;

  // ── Streaming throttle ────────────────────────────────────────────────────
  static const Duration _barThrottle = Duration(milliseconds: 180);
  DateTime _lastBarPush = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _barFlushTimer;
  late BarState _pendingBarState = BarState.idle;
  late String _pendingBarMessage = '';

  // ── Volume delegates ───────────────────────────────────────────────────────
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> ttsEnabledNotifier = ValueNotifier<bool>(true);

  bool _ttsEnabled = true;

  // ── Proactive ──────────────────────────────────────────────────────────────
  int? _currentTriggerId;
  String? _currentTriggerLabel;
  String? _currentTriggerType;
  Map<String, dynamic>? _currentTriggerData;
  Timer? _proactiveTimeout;
  Timer? _thinkingTimer;

  // ── Bandit RL engagement tracking ──────────────────────────────────────────
  // When a proactive trigger fires, we start a 30s engagement window.
  // If the user sends any message within 30s → engaged=true.
  // If they don't → engaged=false (ignored).
  // This is the ACTUAL learning signal for the bandit. Without it,
  // engagement scores stay at 1.0 forever and the bandit picks randomly.
  Timer? _engagementTimer;
  int? _pendingEngagementTriggerId;
  String? _pendingEngagementTriggerType;
  DateTime? _proactiveFiredAt;
  static const Duration _kEngagementWindow = Duration(seconds: 30);

  void _startEngagementWindow(int triggerId, String triggerType) {
    _pendingEngagementTriggerId = triggerId;
    _pendingEngagementTriggerType = triggerType;
    _proactiveFiredAt = DateTime.now();
    _engagementTimer?.cancel();
    _engagementTimer = Timer(_kEngagementWindow, () {
      // User did NOT respond within 30s → record as ignored (negative signal)
      _recordEngagement(false);
    });
  }

  void _recordEngagement(bool engaged) {
    final triggerId = _pendingEngagementTriggerId;
    final triggerType = _pendingEngagementTriggerType;
    if (triggerId == null) return;

    _engagementTimer?.cancel();
    _pendingEngagementTriggerId = null;
    _pendingEngagementTriggerType = null;

    // Only record for Rust bandit triggers (positive IDs).
    // Dart-originated triggers (clock/idle/debug) use negative IDs and
    // don't exist in the Rust triggers table.
    if (triggerId > 0) {
      debugPrint(
        '[BANDIT_RL] Recording engagement: trigger=$triggerId '
        'type=$triggerType engaged=$engaged',
      );
      unawaited(
        auraRecordEngagement(triggerId: triggerId, engaged: engaged)
            .then((_) {
              debugPrint('[BANDIT_RL] Engagement recorded successfully');
            })
            .catchError((e) {
              debugPrint('[BANDIT_RL] Failed to record engagement: $e');
            }),
      );
      // Log the proactive event to the RL timeline so the bandit can learn.
      unawaited(
        auraLogProactive(
          triggerId: triggerId,
          label: _currentTriggerLabel ?? 'unknown',
          triggerType: triggerType ?? 'bandit',
          engaged: engaged,
        ).catchError((e) {
          debugPrint('[BANDIT_RL] Failed to log proactive event: $e');
        }),
      );
    }

    // Also update Dart-side category weights for non-bandit triggers
    if (triggerType != null) {
      ProactiveScheduler.instance.recordFeedback(
        category: triggerType,
        engaged: engaged,
      );
    }
  }

  // ── Vision / context sensing ───────────────────────────────────────────────
  Timer? _healthWarningTimer;
  DateTime? _lastHealthWarningAt;

  // Headless webcam gesture watch: polls the Rust webcam for a pending wave
  // and triggers an immediate AURA greeting. The Rust side keeps the camera
  // alive (headless, no display window) only while this poll is running.
  Timer? _gestureWatchTimer;
  DateTime? _lastGestureGreetingAt;
  final Map<String, int> _androidTopicCounts = {};
  final Set<String> _androidStuckTopicsFired = {};

  // ── Bar state ──────────────────────────────────────────────────────────────
  BarState _state = BarState.idle;
  BarState get currentState => _state;
  String get currentResponse => _currentResponse;

  void _clearProactiveTrigger() {
    _currentTriggerId = null;
    _currentTriggerLabel = null;
    _currentTriggerType = null;
    _currentTriggerData = null;
  }
}
