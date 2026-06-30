import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Host interface supplied by the bar window state so internal helpers can
/// reach the window controller and the mounted lifecycle without importing
/// the widget file directly.
abstract class BarWindowAppHost {
  WindowController? get controller;
  bool get mounted;
}
