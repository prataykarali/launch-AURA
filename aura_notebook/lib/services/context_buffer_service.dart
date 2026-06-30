import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../src/rust/api.dart' as rust;
import '../bar/bar_state.dart';
import 'android_overlay_service.dart';

/// Status model parsed from aura_get_buffer_status() JSON.
class BufferStatus {
  final bool interceptNeeded;
  final String message;
  final int turns;
  final int tokens;
  final double drift;

  const BufferStatus({
    required this.interceptNeeded,
    required this.message,
    required this.turns,
    required this.tokens,
    this.drift = 0.0,
  });

  factory BufferStatus.fromJson(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return BufferStatus(
        interceptNeeded: m['intercept_needed'] as bool? ?? false,
        message: m['message'] as String? ?? '',
        turns: m['turns'] as int? ?? 0,
        tokens: m['tokens'] as int? ?? 0,
        drift: (m['drift'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return const BufferStatus(
        interceptNeeded: false,
        message: '',
        turns: 0,
        tokens: 0,
      );
    }
  }

  factory BufferStatus.empty() => const BufferStatus(
        interceptNeeded: false,
        message: '',
        turns: 0,
        tokens: 0,
      );
}

/// Periodic polling service for context-buffer status.
///
/// Usage:
/// ```dart
/// final svc = ContextBufferService(
///   onStateChange: (state, msg) => setState(() { ... }),
/// );
/// svc.start();
/// // ... on dispose:
/// svc.stop();
/// ```
class ContextBufferService {
  /// Called whenever the BarState or learning message changes.
  final void Function(BarState state, String? learningMessage) onStateChange;

  /// How often to poll the Rust engine (default: 5 s).
  final Duration pollInterval;

  Timer? _timer;
  bool _interceptActive = false;
  bool _disposed = false;

  ContextBufferService({
    required this.onStateChange,
    this.pollInterval = const Duration(seconds: 5),
  });

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void start() {
    _disposed = false;
    _timer ??= Timer.periodic(pollInterval, (_) => _poll());
  }

  void stop() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  // ── Polling ─────────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    if (_disposed) return;

    try {
      final raw = await rust.auraGetBufferStatus();
      final status = BufferStatus.fromJson(raw);

      if (status.interceptNeeded && !_interceptActive) {
        // Transition → learning
        _interceptActive = true;
        onStateChange(BarState.learning, status.message.isNotEmpty
            ? status.message
            : 'Please wait, AURA is learning about you...');

        // Notify Android overlay
        await AndroidOverlayService.updateState(
          BarState.learning,
          message: 'AURA is learning about you...',
        );
      } else if (!status.interceptNeeded && _interceptActive) {
        // Engine has reset the buffer — dismiss overlay
        _interceptActive = false;
        onStateChange(BarState.idle, null);
        await AndroidOverlayService.updateState(BarState.idle);
      }
    } catch (e) {
      debugPrint('ContextBufferService: poll error: $e');
    }
  }

  // ── Overlay widget ──────────────────────────────────────────────────────────

  /// Build a full-screen learning overlay that blocks user input.
  /// Call this from the bar widget when state == BarState.learning.
  static Widget buildLearningOverlay(String message) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0E0628).withOpacity(0.88),
              const Color(0xFF1a0a3d).withOpacity(0.95),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing indigo orb
              _PulsingOrb(),
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF818CF8), Color(0xFFA78BFA)],
                ).createShader(b),
                child: Text(
                  message.isNotEmpty
                      ? message
                      : 'Please wait, AURA is learning about you...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty
                    ? message
                    : 'Consolidating your memories...',
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pulsing orb widget ────────────────────────────────────────────────────────

class _PulsingOrb extends StatefulWidget {
  @override
  State<_PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<_PulsingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 64 + 12 * _anim.value,
        height: 64 + 12 * _anim.value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color.lerp(
                const Color(0xFF818CF8),
                const Color(0xFFA78BFA),
                _anim.value,
              )!,
              const Color(0xFF0E0628).withOpacity(0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF818CF8).withOpacity(0.4 + 0.3 * _anim.value),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
