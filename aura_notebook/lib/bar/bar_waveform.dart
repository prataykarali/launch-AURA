import 'dart:math';
import 'package:flutter/material.dart';
import '../services/stt_service.dart';
import 'bar_state.dart';

class AuraWaveform extends StatefulWidget {
  final BarState state;
  const AuraWaveform({super.key, required this.state});

  @override
  State<AuraWaveform> createState() => _AuraWaveformState();
}

class _AuraWaveformState extends State<AuraWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final Random _rng = Random();
  List<double> _heights = [];
  int _count = 32;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: widget.state.waveDuration)
          ..repeat()
          ..addListener(_tick);
  }

  void _initHeights(int count) {
    if (_heights.length != count) {
      _heights = List.generate(count, (_) => 0.15 + _rng.nextDouble() * 0.35);
      _count = count;
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      final t = _ctrl.value;
      for (int i = 0; i < _count; i++) {
        final target = _target(i, t);
        _heights[i] += (target - _heights[i]) * 0.22;
        _heights[i] += (_rng.nextDouble() - 0.5) * widget.state.jitter;
        _heights[i] = _heights[i].clamp(0.04, 1.0);
      }
    });
  }

  double _target(int i, double t) {
    final center = _count / 2;
    final dist = (i - center).abs() / center;
    switch (widget.state) {
      case BarState.idle:
        return 0.1 + sin(t * 2 * pi + i * 0.5) * 0.07;
      case BarState.listening:
        final micLevel = AuraSTTService.instance.soundLevelNotifier.value;
        // Gentle wave when silent, expanding up to full height with speaker's voice
        return 0.12 + (sin(t * 2 * pi * 3.0 + i * 0.5) * 0.08) + micLevel * 0.8;
      case BarState.speaking:
        // Large, dramatic waveform to visually show AURA is talking.
        // Peak near center, cascading to edges with rich oscillation.
        return (1.0 - dist * 0.45) *
            (0.65 + sin(t * 2 * pi * 3.8 + i * 0.32) * 0.52);
      case BarState.processing:
        // Traveling pulse + breathing glow. A bright Gaussian-shaped bump sweeps
        // left→right across the bar over the animation cycle (t ∈ [0,1)), while
        // the whole waveform gently swells/falls underneath ("breathing") so the
        // bar never looks frozen while AURA is thinking.
        //
        //   breath  = slow global amplitude modulation (0.15 ± 0.10)
        //   pulse   = moving peak; each bar contributes by its distance from it
        //
        // Returns a target height in the same 0..1 space as the other states;
        // _tick() lerps toward it and clamps to [0.04, 1.0], so no bounds guard
        // is needed here.
        const pulseSpeed = 1.0; // one traversal per animation cycle
        const breathAmp = 0.10;
        const pulseAmp = 0.55;
        const sigma = 3.5; // Gaussian width in bars (~narrow, focused peak)
        final pulsePos = (t * pulseSpeed) * _count;
        final dist = i - pulsePos;
        final gauss = exp(-(dist * dist) / (2 * sigma * sigma));
        final breath = 0.15 + sin(t * 2 * pi * 0.8) * breathAmp;
        return breath + pulseAmp * gauss;
      case BarState.proactive:
        return 0.22 + sin(t * 2 * pi * 1.2 + i * 0.6) * 0.22;
      case BarState.learning:
        return 0.15 + sin(t * 2 * pi * 0.8 + i * 0.3) * 0.12;
      case BarState.wakeListening:
        return 0.12 + sin(t * 2 * pi * 0.5 + i * 0.4) * 0.08;
      case BarState.watching:
        // Scanning ripple: a narrow wave sweeps left→right like a radar sweep,
        // giving the impression of AURA actively scanning the scene.
        final scanPos = (t * 1.4) * _count;
        final scanDist = (i - scanPos % _count).abs();
        final scanPeak = exp(-(scanDist * scanDist) / 8.0);
        return 0.10 + sin(t * 2 * pi * 1.8 + i * 0.45) * 0.08 + scanPeak * 0.45;
      case BarState.warning:
        final pulse = sin(t * 2 * pi * 2.0).abs();
        return 0.12 + pulse * (1.0 - dist * 0.35) * 0.55;
    }
  }

  @override
  void didUpdateWidget(AuraWaveform old) {
    super.didUpdateWidget(old);
    if (widget.state != old.state) {
      _ctrl.duration = widget.state.waveDuration;
      _ctrl
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Fewer bars on phone, more on wide laptop
    final count = screenW < 600 ? 22 : (screenW < 900 ? 28 : 36);
    _initHeights(count);

    final colors = widget.state.waveColors;
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_count, (i) {
          final t = i / _count;
          final c = Color.lerp(colors.first, colors.last, t)!;
          final h = (_heights[i] * 34).clamp(3.0, 34.0);
          return Container(
            width: 2.5,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: c,
              boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 4)],
            ),
          );
        }),
      ),
    );
  }
}
