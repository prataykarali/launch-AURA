part of 'android_overlay_service.dart';

/// Show a user-visible notice when the overlay permission was denied, with a
/// button that opens the app's system settings page so the user can grant
/// "Display over other apps" manually.
void _showPermissionDeniedNotice(BuildContext? context) {
  // Prefer a live root navigator context so the notice shows even when the
  // caller's widget (e.g. LoadingScreen) has been unmounted by the time we
  // get here. main.dart sets rootNavigatorKey in AuraApp.build().
  final liveContext = AndroidOverlayService._resolveContext(context);
  if (liveContext == null) {
    debugPrint(
      'AURA_OVERLAY: no live context to show permission notice '
      '(rootNavigatorKey not set or not mounted).',
    );
    return;
  }
  final scaffoldMessenger = ScaffoldMessenger.maybeOf(liveContext);
  if (scaffoldMessenger == null) {
    debugPrint(
      'AURA_OVERLAY: no ScaffoldMessenger in context — '
      'cannot show permission notice.',
    );
    return;
  }

  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: const Text(
        'AURA Bar needs "Display over other apps" permission. '
        'Tap to open Settings.',
        style: TextStyle(fontSize: 13),
      ),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Settings',
        onPressed: () async {
          // Open the app's detail settings page where the user can grant
          // "Display over other apps" (SYSTEM_ALERT_WINDOW permission).
          try {
            await const MethodChannel(
              'aura/main_app',
            ).invokeMethod('open_app_settings');
          } catch (_) {
            // Fallback: open the main app so the user can navigate manually.
          }
        },
      ),
    ),
  );
}
