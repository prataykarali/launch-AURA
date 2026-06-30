import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuraWindowManager with WindowListener {
  static final AuraWindowManager instance = AuraWindowManager._();
  AuraWindowManager._();

  bool _quitting = false;
  bool _isBarMode = true;
  Offset? _savedBarPosition;
  void Function()? onCollapse;

  bool get isBarMode => _isBarMode;

  static const _kPrefX = 'bar_x';
  static const _kPrefY = 'bar_y';
  static const _kBarW = 1200.0;
  // Keep in sync with the bar_window_app.dart child-window height (220). The
  // bar content is bottom-aligned, so a taller window just gives the response
  // bubble more room to render without being clipped.
  static const _kBarH = 220.0;

  Future<void> init() async {
    if (!Platform.isLinux) return;
    windowManager.addListener(this);

    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(_kBarW, _kBarH),
        backgroundColor: Color(0x00000000),
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
        alwaysOnTop: true,
      ),
      () async {
        await windowManager.setResizable(false);
        await windowManager.setAsFrameless();

        final prefs = await SharedPreferences.getInstance();
        final x = prefs.getDouble(_kPrefX);
        final y = prefs.getDouble(_kPrefY);
        if (x != null && y != null) {
          _savedBarPosition = Offset(x, y);
          await windowManager.setPosition(_savedBarPosition!);
        } else {
          await windowManager.setPosition(const Offset(160, 880));
        }
        await windowManager.show();
      },
    );
  }

  Future<void> expandToApp() async {
    // Legacy API: the bar now lives in its own dedicated child window.
    // Keep this as a harmless focus call so old launch paths cannot create
    // the previous black 900x700 host window.
    if (!_isBarMode) return;
    await windowManager.focus();
  }

  Future<void> collapseToBar() async {
    if (_isBarMode) return;
    _isBarMode = true;
    onCollapse?.call();

    await windowManager.setResizable(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setSize(const Size(_kBarW, _kBarH));
    await windowManager.setBackgroundColor(const Color(0x00000000));
    await windowManager.setAsFrameless();

    if (_savedBarPosition != null) {
      await windowManager.setPosition(_savedBarPosition!);
    }
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> quit() async {
    _quitting = true;
    await windowManager.hide();
  }

  @override
  void onWindowClose() async {
    if (_quitting) {
      await windowManager.hide();
      return;
    }
    if (!_isBarMode) {
      await collapseToBar();
    } else {
      await quit();
    }
  }

  @override
  void onWindowBlur() async {
    if (_isBarMode) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (_isBarMode) await windowManager.setAlwaysOnTop(true);
    }
  }
}
