// lib/utils/responsive.dart
import 'dart:io';
import 'package:flutter/material.dart';

/// Global responsive utility — works for Android, Linux, Windows, Mac
class R {
  R._();

  // ── Platform checks ───────────────────────────────────────────────────────
  static bool get isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  static bool get isMobile =>
      Platform.isAndroid || Platform.isIOS;

  // ── Screen size breakpoints ───────────────────────────────────────────────
  static bool isPhone(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < 600;
  static bool isTablet(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600 &&
          MediaQuery.of(ctx).size.width < 1024;
  static bool isLaptop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 1024;

  // ── Font sizes ────────────────────────────────────────────────────────────
  static double fs(BuildContext ctx, double mobileSize) {
    if (isLaptop(ctx)) return mobileSize * 1.3;
    if (isTablet(ctx)) return mobileSize * 1.15;
    return mobileSize;
  }

  // ── Padding ───────────────────────────────────────────────────────────────
  static double pad(BuildContext ctx, double mobilePad) {
    if (isLaptop(ctx)) return mobilePad * 1.8;
    if (isTablet(ctx)) return mobilePad * 1.4;
    return mobilePad;
  }

  // ── Icon sizes ────────────────────────────────────────────────────────────
  static double icon(BuildContext ctx, double mobileSize) {
    if (isLaptop(ctx)) return mobileSize * 1.4;
    if (isTablet(ctx)) return mobileSize * 1.2;
    return mobileSize;
  }

  // ── Card width (constrain wide layouts) ───────────────────────────────────
  static double cardWidth(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (isLaptop(ctx)) return (w * 0.5).clamp(400, 700);
    if (isTablet(ctx)) return w * 0.75;
    return w;
  }

  // ── Image BoxFit ──────────────────────────────────────────────────────────
  static BoxFit imageFit(BuildContext ctx) {
    if (isLaptop(ctx)) return BoxFit.contain;
    return BoxFit.cover;
  }

  // ── Max content width (centers content on wide screens) ──────────────────
  static Widget maxWidth(Widget child, {double max = 700}) =>
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: max),
          child: child,
        ),
      );
}