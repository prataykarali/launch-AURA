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
  static const Duration _kDebugInterval = Duration(minutes: 1);

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

  // Cooldown — 20 minutes minimum between proactive triggers so AURA
  // feels like a quiet companion, not a notification spammer.
  static const Duration cooldownDuration = Duration(minutes: 20);
  static const Duration _kDesktopMinInterval = Duration(minutes: 15);
  static const Duration _kDesktopMaxInterval = Duration(minutes: 30);
  static const Duration _kAndroidPollInterval = Duration(minutes: 15);

  // Idle-uptime threshold: after this much silence the user is considered idle.
  static const Duration idleThreshold = Duration(minutes: 10);
  DateTime? _lastIdleTrigger; // avoid firing idle_checkin back-to-back

  // Keep track of times checked today to avoid duplicate trigger within the same hour
  final Set<int> _triggeredHours = {};

  void start() {
    _timer?.cancel();

    if (_kDebugTestMode) {
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
        'AuraProactiveScheduler: started (production mode, '
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
        _rng.nextInt(span.inMilliseconds + 1);
    final jitter = 0.85 + (_rng.nextDouble() * 0.30);
    final adjusted = (baseMs * _cadenceBias * jitter)
        .clamp(
          const Duration(minutes: 1).inMilliseconds,
          const Duration(minutes: 12).inMilliseconds,
        )
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
