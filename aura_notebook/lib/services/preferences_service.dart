import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  // Single opt-in that gates ALL network egress for optional features:
  // online translation AND online text-to-speech. One user-facing toggle
  // controls both, so they share the same underlying key.
  static const String _keyOnlineServices = 'enable_online_translation';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get whether online services (translation + TTS) are enabled.
  /// Returns false by default (privacy-first: no network egress by default).
  Future<bool> getOnlineServicesEnabled() async {
    await init();
    return _prefs?.getBool(_keyOnlineServices) ?? false;
  }

  /// Set whether online services (translation + TTS) are enabled.
  Future<void> setOnlineServicesEnabled(bool enabled) async {
    await init();
    await _prefs?.setBool(_keyOnlineServices, enabled);
  }

  /// Backwards-compatible aliases. Online translation and online TTS share a
  /// single opt-in, so these delegate to the unified online-services setting.
  Future<bool> getOnlineTranslationEnabled() => getOnlineServicesEnabled();

  Future<void> setOnlineTranslationEnabled(bool enabled) =>
      setOnlineServicesEnabled(enabled);
}
