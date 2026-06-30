import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../bar/bar_state.dart';
import '../tts_service.dart';

part 'permission_notice.dart';

class AndroidOverlayService {
  /// Global navigator key owned by the root app widget (set from main.dart).
  /// Lets showBar() resolve a live ScaffoldMessenger even when called from a
  /// background callback, a disposed LoadingScreen context, or a resume
  /// lifecycle event. Without this, the permission-denied SnackBar silently
  /// no-op'd (ScaffoldMessenger.maybeOf returned null on the stale context)
  /// and the overlay never appeared — leaving no on-screen hint about why.
  static GlobalKey<NavigatorState>? rootNavigatorKey;
  static bool _batteryOptimizationRequestAttempted = false;

  /// Resolve a live BuildContext from the global navigator key. Returns null
  /// if no navigator is mounted yet. Falls back to any caller-supplied context.
  static BuildContext? _resolveContext(BuildContext? context) {
    if (context != null && context.mounted) return context;
    return rootNavigatorKey?.currentContext;
  }

  // ── Overlay dimensions ─────────────────────────────────────────────────────
  //
  // Keep Android's native overlay compact and draggable. The Flutter widget
  // itself handles its internal bubble/pill positioning, so the OS window must
  // not be a tall bottom-anchored surface; that makes the visible pill appear
  // "stuck" or disappear behind the app underneath on some Samsung builds.

  static const int _kBubbleHeight = 82;
  static const int _kBarPillHeight = 86;
  static const int _kOverlayWidthPhone = 420;
  static const int _kOverlayWidthTablet = 780;
  static const int _kSpacing = 8;
  static const int _kSafetyBuffer = 14;

  /// Compute the correct overlay height in dp for the current state.
  static int overlayHeightForState(BarState state) {
    // Keep Android's OS overlay window size stable. On Samsung/One UI,
    // repeated resizeOverlay calls during startup can recenter the floating
    // window, making the bar look like it is dancing. The widget can render
    // idle/processing/speaking states inside this fixed surface.
    return _kBubbleHeight + _kSpacing + _kBarPillHeight + _kSafetyBuffer;
  }

  static int overlayWidthForWindow() {
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final width = view != null
        ? view.physicalSize.width / view.devicePixelRatio
        : 0.0;
    if (width <= 0) return _kOverlayWidthPhone;
    final desired = width < 600
        ? width - 24.0
        : _kOverlayWidthTablet.toDouble();
    return desired.clamp(280.0, _kOverlayWidthTablet.toDouble()).round();
  }

  // ── Show / hide ────────────────────────────────────────────────────────────

  static Future<void> showBar({
    BuildContext? context,
    bool? muted,
    bool allowSystemPrompts = false,
  }) async {
    // Unconditional entry log so we can ALWAYS tell whether showBar() was
    // reached — the earlier symptom was "no AURA_OVERLAY lines at all",
    // which meant this function was never even called.
    debugPrint(
      'AURA_OVERLAY: showBar() called, isAndroid=$Platform.isAndroid muted=$muted',
    );
    if (!Platform.isAndroid) return;
    AuraTTSService.instance.setPlaybackSuppressed(false);

    // ── Request overlay permission ────────────────────────────────────────────
    // On Samsung One UI / Android 14+, requestPermission() opens Settings and
    // often returns null because the activity result never arrives back.
    // We re-check isPermissionGranted() afterwards to handle this gracefully.
    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint('AURA_OVERLAY: isPermissionGranted=$granted');
    if (!granted) {
      // requestPermission returns a bool (granted immediately, e.g. on devices
      // where the Settings screen is optional) or null (user has to grant in
      // Settings). Capture it so we don't re-prompt needlessly.
      final immediate = await FlutterOverlayWindow.requestPermission();
      debugPrint('AURA_OVERLAY: requestPermission returned=$immediate');
      // Re-check after the user returns from Settings. The 500ms delay is a
      // best-effort; on resume we also retry via the lifecycle observer in
      // main.dart (didChangeAppLifecycleState → resumed).
      await Future<void>.delayed(const Duration(milliseconds: 500));
      granted =
          (immediate == true) ||
          await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        debugPrint(
          'AURA_OVERLAY: Permission NOT granted after request — '
          'showing notice and bailing. Will retry on app resume.',
        );
        _showPermissionDeniedNotice(null);
        return;
      }
    }

    if (await FlutterOverlayWindow.isActive()) {
      // Overlay already active — just push the mute state if provided
      if (muted != null) {
        await updateState(BarState.idle, muted: muted);
      }
      return;
    }

    // ── Bypass Samsung / OEM battery optimization that kills the overlay service ─
    // This opens a system Activity, so never do it repeatedly while the bar is
    // already active or while TTS is speaking. One prompt per app session is
    // enough; repeated calls feel like AURA is redirecting the user.
    if (allowSystemPrompts && !_batteryOptimizationRequestAttempted) {
      _batteryOptimizationRequestAttempted = true;
      try {
        const channel = MethodChannel('aura/main_app');
        final alreadyIgnored =
            await channel.invokeMethod<bool>('check_battery_optimization') ??
            true;
        if (!alreadyIgnored) {
          await channel.invokeMethod('request_battery_optimization');
        }
      } catch (e) {
        debugPrint('AURA_OVERLAY: Battery optimization bypass unavailable: $e');
      }
    } else if (!allowSystemPrompts) {
      debugPrint(
        'AURA_OVERLAY: skipping system battery prompt for normal overlay show',
      );
    }

    final height = overlayHeightForState(BarState.idle);

    // Small delay to ensure the overlay service is fully started on Samsung
    await Future<void>.delayed(const Duration(milliseconds: 300));

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'AURA Bar',
        overlayContent: 'AURA floating assistant',
        width: overlayWidthForWindow(),
        height: height,
        alignment: OverlayAlignment.center,
        positionGravity: PositionGravity.none,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
      );
      debugPrint('AURA_OVERLAY: shown height=${height}dp draggable');
    } catch (e) {
      debugPrint('AURA_OVERLAY: Error showing overlay: $e');
      // Retry once after a short delay (Samsung sometimes needs a second attempt)
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'AURA Bar',
          overlayContent: 'AURA floating assistant',
          width: overlayWidthForWindow(),
          height: height,
          alignment: OverlayAlignment.center,
          positionGravity: PositionGravity.none,
          visibility: NotificationVisibility.visibilityPublic,
          flag: OverlayFlag.defaultFlag,
        );
        debugPrint(
          'AURA_OVERLAY: retry succeeded height=${height}dp draggable',
        );
      } catch (e2) {
        debugPrint('AURA_OVERLAY: Retry also failed: $e2');
      }
    }
  }

  // Last state we logged. The overlay isolate owns native resize calls so it can
  // preserve drag state consistently while applying the latest width/height.
  static String? _lastOverlayState;

  static Future<void> updateState(
    BarState state, {
    String? message,
    bool? muted,
  }) async {
    if (!Platform.isAndroid) return;
    if (!await FlutterOverlayWindow.isActive()) return;

    final height = overlayHeightForState(state);

    // Include the authoritative mute state when provided so the overlay's
    // _isMuted mirror can re-sync from the main process (not just from its own
    // optimistic toggle). The overlay listener honors `muted` only when present.
    final payload = <String, dynamic>{
      'action': 'update',
      'state': state.name,
      'message': message,
      'width': overlayWidthForWindow(),
      'height': height,
    };
    if (muted != null) payload['muted'] = muted;
    debugPrint('AURA_OVERLAY_SERVICE: updateState sending payload=$payload');
    await FlutterOverlayWindow.shareData(jsonEncode(payload));

    // Avoid log spam during streaming: only log on a state transition, not on
    // every message update within the same state.
    if (_lastOverlayState != state.name) {
      debugPrint('AURA_OVERLAY: state=${state.name} height=${height}dp');
      _lastOverlayState = state.name;
    }
  }

  /// Warns in debug mode if the overlay dimensions may cause visible boundary
  /// bleed outside the AURA Bar widget bounds.
  ///
  /// Call this after showing the overlay in debug builds.
  static void verifyTranslucency(BarState state) {
    if (!Platform.isAndroid) return;

    final maxExpected = overlayHeightForState(
      BarState.learning,
    ); // largest case
    final actual = overlayHeightForState(state);

    if (actual > maxExpected + 20) {
      debugPrint(
        '[AURA_OVERLAY_WARN] Overlay height ${actual}dp exceeds expected '
        'max ${maxExpected}dp — potential black boundary leak! '
        'Ensure background_color is fully transparent (ARGB 0x00000000).',
      );
    } else {
      debugPrint(
        '[AURA_OVERLAY] Translucency OK: state=${state.name} '
        'height=${actual}dp ≤ max=${maxExpected}dp',
      );
    }
  }

  static Future<void> closeBar() async {
    if (!Platform.isAndroid) return;
    AuraTTSService.instance.setPlaybackSuppressed(true);
    await FlutterOverlayWindow.closeOverlay();
  }

  /// True when the overlay window is currently active (shown). Safe to call on
  /// any platform (returns false off-Android). Used by the resume-lifecycle
  /// hook in main.dart to decide whether to retry showing the bar after the
  /// user returns from granting the "Display over other apps" permission.
  static Future<bool> isActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }

  /// Called on app resume (user navigated back from Settings). If permission
  /// is now granted but the overlay isn't active yet, show it. This is the
  /// fallback path that closes the "permission denied, then never retried"
  /// gap: previously a user who granted the permission in Settings returned
  /// to the app and saw no bar, with no way to retrigger showBar().
  static Future<void> retryIfNotActive({bool? muted}) async {
    if (!Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    final active = await isActive();
    debugPrint(
      'AURA_OVERLAY: resume check — granted=$granted active=$active muted=$muted',
    );
    if (granted && !active) {
      await showBar(muted: muted, allowSystemPrompts: false);
    } else if (granted && active && muted != null) {
      // Overlay already active, just push the mute state
      await updateState(BarState.idle, muted: muted);
    }
  }
}
