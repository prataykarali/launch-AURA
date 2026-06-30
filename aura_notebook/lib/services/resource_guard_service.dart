import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ResourcePressureSnapshot {
  const ResourcePressureSnapshot({
    required this.rssBytes,
    this.totalBytes,
    this.availableBytes,
    required this.sampledAt,
  });

  final int rssBytes;
  final int? totalBytes;
  final int? availableBytes;
  final DateTime sampledAt;

  double? get systemUsedFraction {
    final total = totalBytes;
    final available = availableBytes;
    if (total == null || total <= 0 || available == null) return null;
    return (1.0 - (available / total)).clamp(0.0, 1.0);
  }

  double? get appUsedFraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (rssBytes / total).clamp(0.0, 1.0);
  }

  String get debugLabel {
    final system = systemUsedFraction;
    final app = appUsedFraction;
    final parts = <String>[
      'rss=${_formatBytes(rssBytes)}',
      if (system != null) 'system=${(system * 100).toStringAsFixed(1)}%',
      if (app != null) 'app=${(app * 100).toStringAsFixed(1)}%',
      if (availableBytes != null) 'available=${_formatBytes(availableBytes!)}',
    ];
    return parts.join(' ');
  }
}

class ResourcePressureEvent {
  const ResourcePressureEvent({
    required this.snapshot,
    required this.appDominant,
    required this.reason,
    required this.cooldown,
  });

  final ResourcePressureSnapshot snapshot;
  final bool appDominant;
  final String reason;
  final Duration cooldown;
}

typedef ResourcePressureCallback =
    FutureOr<void> Function(ResourcePressureEvent event);

class ResourceGuardService {
  ResourceGuardService._();
  static final ResourceGuardService instance = ResourceGuardService._();

  static const Duration _kPollInterval = Duration(seconds: 3);
  static const Duration _kHighPressurePause = Duration(seconds: 10);
  static const Duration _kCriticalPause = Duration(seconds: 45);
  static const Duration _kWarningCooldown = Duration(seconds: 25);

  static const double _kSystemHighFraction = 0.88;
  static const double _kSystemCriticalFraction = 0.95;
  static const double _kAppHighFraction = 0.55;
  static const double _kAppCriticalFraction = 0.70;
  static const int _kAppCriticalRssBytes = 4 * 1024 * 1024 * 1024;

  Timer? _timer;
  DateTime? _nonEssentialPausedUntil;
  DateTime? _lastCriticalWarningAt;
  int _pressureEpisodeLevel = 0;
  ResourcePressureCallback? _onCritical;

  final ValueNotifier<ResourcePressureSnapshot?> snapshotNotifier =
      ValueNotifier<ResourcePressureSnapshot?>(null);

  bool get isRunning => _timer != null;
  bool get isThrottled {
    final pausedUntil = _nonEssentialPausedUntil;
    return pausedUntil != null && DateTime.now().isBefore(pausedUntil);
  }

  bool get shouldAcceptSensoryWork => !isThrottled;

  void start({ResourcePressureCallback? onCritical}) {
    _onCritical = onCritical ?? _onCritical;
    if (_timer != null) return;
    _timer = Timer.periodic(_kPollInterval, (_) => _sampleAndAct());
    unawaited(_sampleAndAct());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _nonEssentialPausedUntil = null;
    _pressureEpisodeLevel = 0;
  }

  void pauseNonEssentialWork(Duration duration) {
    final until = DateTime.now().add(duration);
    if (_nonEssentialPausedUntil == null ||
        until.isAfter(_nonEssentialPausedUntil!)) {
      _nonEssentialPausedUntil = until;
      debugPrint(
        '[AURA_HEALTH] nonessential sensory work paused for '
        '${duration.inSeconds}s',
      );
    }
  }

  Future<void> _sampleAndAct() async {
    final snapshot = await _sample();
    if (snapshot == null) return;
    snapshotNotifier.value = snapshot;

    final systemUsed = snapshot.systemUsedFraction;
    final appUsed = snapshot.appUsedFraction;
    final appHigh =
        (appUsed != null && appUsed >= _kAppHighFraction) ||
        snapshot.rssBytes >= _kAppCriticalRssBytes;
    final appCritical =
        (appUsed != null && appUsed >= _kAppCriticalFraction) ||
        snapshot.rssBytes >= _kAppCriticalRssBytes;
    final systemHigh = systemUsed != null && systemUsed >= _kSystemHighFraction;
    final systemCritical =
        systemUsed != null && systemUsed >= _kSystemCriticalFraction;

    if (!systemHigh && !appHigh) {
      if (_pressureEpisodeLevel != 0) {
        debugPrint('[AURA_HEALTH] pressure recovered: ${snapshot.debugLabel}');
      }
      _pressureEpisodeLevel = 0;
      return;
    }

    final pressureLevel = systemCritical || appCritical ? 2 : 1;
    if (pressureLevel > _pressureEpisodeLevel || !isThrottled) {
      pauseNonEssentialWork(
        pressureLevel == 2 ? _kCriticalPause : _kHighPressurePause,
      );
      _pressureEpisodeLevel = pressureLevel;
    }

    debugPrint('[AURA_HEALTH] pressure sample: ${snapshot.debugLabel}');

    if (!systemCritical && !appCritical) return;

    final now = DateTime.now();
    if (_lastCriticalWarningAt != null &&
        now.difference(_lastCriticalWarningAt!) < _kWarningCooldown) {
      return;
    }
    _lastCriticalWarningAt = now;

    final event = ResourcePressureEvent(
      snapshot: snapshot,
      appDominant: appCritical,
      reason: appCritical ? 'app-memory' : 'system-memory',
      cooldown: _kCriticalPause,
    );
    await _onCritical?.call(event);
  }

  Future<ResourcePressureSnapshot?> _sample() async {
    try {
      final rss = ProcessInfo.currentRss;
      final memInfo = await _readProcMemInfo();
      return ResourcePressureSnapshot(
        rssBytes: rss,
        totalBytes: memInfo.totalBytes,
        availableBytes: memInfo.availableBytes,
        sampledAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AURA_HEALTH] sample failed: $e');
      return null;
    }
  }

  Future<({int? totalBytes, int? availableBytes})> _readProcMemInfo() async {
    if (!Platform.isLinux && !Platform.isAndroid) {
      return (totalBytes: null, availableBytes: null);
    }

    final file = File('/proc/meminfo');
    if (!await file.exists()) {
      return (totalBytes: null, availableBytes: null);
    }

    int? total;
    int? available;
    final lines = await file.readAsLines();
    for (final line in lines) {
      if (line.startsWith('MemTotal:')) {
        total = _parseMemInfoKb(line);
      } else if (line.startsWith('MemAvailable:')) {
        available = _parseMemInfoKb(line);
      }
      if (total != null && available != null) break;
    }
    return (totalBytes: total, availableBytes: available);
  }

  int? _parseMemInfoKb(String line) {
    final match = RegExp(r'(\d+)').firstMatch(line);
    final kb = match == null ? null : int.tryParse(match.group(1)!);
    return kb == null ? null : kb * 1024;
  }
}

String _formatBytes(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes >= gib) return '${(bytes / gib).toStringAsFixed(2)}GiB';
  return '${(bytes / mib).toStringAsFixed(0)}MiB';
}
