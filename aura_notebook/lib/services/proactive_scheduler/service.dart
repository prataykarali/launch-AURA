import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../src/rust/api.dart';
import '../bar_brain.dart';
import '../android_overlay_service.dart';
import '../resource_guard_service.dart';
import '../tts_service.dart';
import '../../bar/bar_multi_window_service.dart';
import '../../bar/bar_state.dart';

part 'debug_logic.dart';
part 'trigger_logic.dart';

class ProactiveScheduler {
  ProactiveScheduler._();
  static final ProactiveScheduler instance = ProactiveScheduler._();

  // ┌──────────────────────────────────────────────────────────────────────────┐
  // │  🔧 DEBUG TEST MODE — set to true to enable 1-minute high-frequency    │
  // │  proactive trigger loop. Set back to false for production schedule.    │
  // └──────────────────────────────────────────────────────────────────────────┘
  static const bool _kDebugTestMode = false;
  static const Duration _kDebugInterval = Duration(seconds: 30);
  // Defense in depth: even if _kDebugTestMode were left true in source, the
  // shipped binary cannot spam unless AURA_DEBUG_PROACTIVE=1 is explicitly set
  // in the environment. This prevents stale-debug-binary yapping forever.
  static final bool _kDebugEnabled =
      _kDebugTestMode && Platform.environment['AURA_DEBUG_PROACTIVE'] == '1';

  Timer? _timer;
  DateTime? _lastActivation;
  int _debugCycleCount = 0;
  final Random _rng = Random();
  double _cadenceBias = 1.0;
  final Map<String, double> _categoryWeights = {
    'bandit': 1.0,
    'clock': 1.0,
    'idle': 1.0,
    'vision': 1.0,
    'speech': 1.0,
    'text': 1.0,
  };

  // Negative trigger IDs mark Dart-originated triggers (clock/idle/debug) so
  // they are visually distinct from Rust bandit triggers (positive DB ids).
  // bar_brain.dart skips auraRecordEngagement for ids <= 0 since those don't
  // exist in the Rust `triggers` table and would corrupt the bandit policy.
  static const int _kMorningId = -1;
  static const int _kAfternoonId = -2;
  static const int _kEveningId = -3;
  static const int _kIdleId = -4;

  /// Wrap a Dart-originated trigger label into the same `{id,label,type}` JSON
  /// shape the Rust CheckScheduler path returns. bar_brain.dart parses this to
  /// extract `id` + `label`. Negative ids tell it this is NOT a bandit trigger.
  String _wrapTrigger(int id, String label, String type) {
    return jsonEncode({'id': id, 'label': label, 'type': type});
  }

  // Fast mode (AURA_PROACTIVE_FAST=1): shorter cooldowns for smoke tests only.
  // Production defaults stay quiet so AURA feels like a companion, not a spammer.
  static final bool _kFastProactive =
      Platform.environment['AURA_PROACTIVE_FAST'] == '1';

  // Cooldown between automated (idle/bandit) proactive triggers.
  // Schedule reminders bypass this — they are user-initiated.
  static Duration get cooldownDuration => _kFastProactive
      ? const Duration(minutes: 3)
      : const Duration(minutes: 20);

  static Duration get _kDesktopMinInterval => _kFastProactive
      ? const Duration(seconds: 45)
      : const Duration(minutes: 15);

  static Duration get _kDesktopMaxInterval => _kFastProactive
      ? const Duration(minutes: 2)
      : const Duration(minutes: 30);

  static Duration get _kAndroidPollInterval => _kFastProactive
      ? const Duration(minutes: 1)
      : const Duration(minutes: 15);

  // Idle-uptime threshold: after this much silence the user is considered idle.
  static Duration get idleThreshold => _kFastProactive
      ? const Duration(minutes: 2)
      : const Duration(minutes: 10);

  // Minimum gap between idle_checkin firings (independent of bandit).
  static Duration get _idleRefireGap => _kFastProactive
      ? const Duration(minutes: 4)
      : const Duration(minutes: 45);

  DateTime? _lastIdleTrigger; // avoid firing idle_checkin back-to-back
  DateTime? _lastScheduleNoteCheck; // avoid firing schedule notes back-to-back
  DateTime? _lastBanditAttempt; // soft throttle on FFI bandit polls

  // Keep track of times checked today to avoid duplicate trigger within the same hour
  final Set<int> _triggeredHours = {};

  // ── Schedule timer management ────────────────────────────────────────────
  // Active schedule timers keyed by the note content hash.
  final Map<String, Timer> _scheduleTimers = {};
  // Already-fired schedule note contents (avoid re-firing).
  final Set<String> _firedScheduleNotes = {};

  static const int _kScheduleReminderId = -6;

  void start() {
    _timer?.cancel();

    if (_kDebugEnabled) {
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      //  DEBUG: 60-second high-frequency proactive test loop
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      _debugCycleCount = 0;
      debugPrint('');
      debugPrint(
        '╔══════════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  [AURA PROACTIVE TEST] 🧪 DEBUG MODE ACTIVE                ║',
      );
      debugPrint(
        '║  Interval: 60 seconds | Cooldown: BYPASSED                 ║',
      );
      debugPrint(
        '║  Clock checks: BYPASSED | Rust FFI: FORCE-CALLED           ║',
      );
      debugPrint(
        '╚══════════════════════════════════════════════════════════════╝',
      );
      debugPrint('');

      // Fire immediately on start, then every 60 seconds
      _debugForceProactiveCycle();
      _timer = Timer.periodic(_kDebugInterval, (_) {
        _debugForceProactiveCycle();
      });
    } else {
      final interval = _nextInterval();
      _timer = Timer(interval, () {
        unawaited(_runProductionCycle());
      });
      debugPrint(
        'AuraProactiveScheduler: started '
        '(${_kFastProactive ? "FAST smoke" : "production"} mode, '
        'idle≥${idleThreshold.inMinutes}m, cooldown=${cooldownDuration.inMinutes}m, '
        'next=${interval.inSeconds}s)',
      );
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _debugCycleCount = 0;
    debugPrint('[AURA PROACTIVE TEST] ⏹  Scheduler stopped');
  }

  Future<void> _runProductionCycle() async {
    try {
      await _checkTriggers();
    } finally {
      if (_timer != null) {
        final next = _nextInterval();
        _timer = Timer(next, () {
          unawaited(_runProductionCycle());
        });
        debugPrint(
          'AuraProactiveScheduler: next randomized check in ${next.inSeconds}s',
        );
      }
    }
  }

  Duration _nextInterval() {
    if (Platform.isAndroid) return _kAndroidPollInterval;
    final span = _kDesktopMaxInterval - _kDesktopMinInterval;
    final baseMs =
        _kDesktopMinInterval.inMilliseconds +
        (span.inMilliseconds > 0 ? _rng.nextInt(span.inMilliseconds + 1) : 0);
    final jitter = 0.85 + (_rng.nextDouble() * 0.30);
    final minMs = _kFastProactive
        ? const Duration(seconds: 30).inMilliseconds
        : const Duration(minutes: 10).inMilliseconds;
    final maxMs = _kFastProactive
        ? const Duration(minutes: 3).inMilliseconds
        : const Duration(minutes: 30).inMilliseconds;
    final adjusted = (baseMs * _cadenceBias * jitter)
        .clamp(minMs, maxMs)
        .round();
    return Duration(milliseconds: adjusted);
  }

  void recordFeedback({required String category, required bool engaged}) {
    final key = category.trim().isEmpty ? 'bandit' : category.trim();
    final current = _categoryWeights[key] ?? 1.0;
    if (engaged) {
      _cadenceBias = (_cadenceBias * 0.9).clamp(0.65, 1.8);
      _categoryWeights[key] = (current + 0.08).clamp(0.5, 1.6);
    } else {
      _cadenceBias = (_cadenceBias * 1.15).clamp(0.65, 1.8);
      _categoryWeights[key] = (current - 0.10).clamp(0.5, 1.6);
    }
    debugPrint(
      'AuraProactiveScheduler: feedback category=$key engaged=$engaged '
      'cadenceBias=${_cadenceBias.toStringAsFixed(2)} '
      'weight=${_categoryWeights[key]!.toStringAsFixed(2)}',
    );
  }
}
