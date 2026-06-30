import 'package:flutter/material.dart';

enum BarState {
  idle,
  listening,
  speaking,
  processing,
  proactive,
  learning,
  wakeListening,
  watching,
  warning,
}

extension BarStateX on BarState {
  bool get isActive =>
      this == BarState.listening ||
      this == BarState.speaking ||
      this == BarState.wakeListening;

  List<Color> get waveColors {
    switch (this) {
      case BarState.idle:
        return [Color(0xFF82B4FF), Color(0xFFC084FC)];
      case BarState.listening:
        return [Color(0xFF67E8F9), Color(0xFF38BDF8)];
      case BarState.speaking:
        return [Color(0xFFFF9CEE), Color(0xFFD5A3FF), Color(0xFF90F0DF)];
      case BarState.processing:
        return [Color(0xFFFFB347), Color(0xFFFF6B6B)];
      case BarState.proactive:
        return [Color(0xFF6EE7B7), Color(0xFF34D399)];
      case BarState.learning:
        // Soft indigo-violet gradient for memory consolidation state
        return [Color(0xFF818CF8), Color(0xFFA78BFA)];
      case BarState.wakeListening:
        // Ambient soft teal and cyan pulse colors
        return [Color(0xFF14B8A6), Color(0xFF06B6D4)];
      case BarState.watching:
        // Electric cyan/teal — vision is active
        return [Color(0xFF00E5FF), Color(0xFF00BCD4), Color(0xFF26C6DA)];
      case BarState.warning:
        return [Color(0xFFFFD166), Color(0xFFFF6B6B)];
    }
  }

  Duration get waveDuration {
    switch (this) {
      case BarState.idle:
        return const Duration(milliseconds: 2400);
      case BarState.listening:
        return const Duration(milliseconds: 440);
      case BarState.speaking:
        return const Duration(milliseconds: 320);
      case BarState.processing:
        return const Duration(milliseconds: 650);
      case BarState.proactive:
        return const Duration(milliseconds: 1100);
      case BarState.learning:
        return const Duration(milliseconds: 1800);
      case BarState.wakeListening:
        return const Duration(milliseconds: 2000);
      case BarState.watching:
        return const Duration(milliseconds: 750);
      case BarState.warning:
        return const Duration(milliseconds: 900);
    }
  }

  double get jitter {
    switch (this) {
      case BarState.idle:
        return 0.008;
      case BarState.listening:
        return 0.09;
      case BarState.speaking:
        return 0.13;
      case BarState.processing:
        return 0.055;
      case BarState.proactive:
        return 0.03;
      case BarState.learning:
        return 0.015;
      case BarState.wakeListening:
        return 0.01;
      case BarState.watching:
        return 0.045;
      case BarState.warning:
        return 0.025;
    }
  }
}
