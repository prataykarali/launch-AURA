/// Store-launchable MVP gates.
///
/// Off by default: overlay bar, proactive/bandit RL, camera/YOLO, wake word.
/// The shipped app is chat + memory + notes + user-tapped voice.
class MvpConfig {
  static const bool overlayBar = true;
  static const bool desktopBarWindow = true;
  static const bool proactive = false;
  static const bool vision = false;
  static const bool requestMicOnLaunch = false;
  static const bool hideMainWindowOnLaunch = false;
}
