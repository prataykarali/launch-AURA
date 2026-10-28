# Android AURA Bar Overlay Diagnostic Report

This document outlines the permissions, layout conflicts, keyboard issues, and lifecycle constraints observed in the floating Android AURA Bar overlay.

---

## 1. Background Microphone Access Restriction

### Root Cause
*   **Location:** [OverlayService.java (line 251-256)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java#L251-L256)
*   Android 14+ (API 34+) requires foreground services to declare specific foreground service types in their manifest and supply matching types to the `startForeground()` method.
*   The main application manifest declares:
    `android:foregroundServiceType="mediaPlayback|microphone"`
*   However, when `OverlayService` is promoted to the foreground, it passes **only** `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK`:
    ```java
    startForeground(OverlayConstants.NOTIFICATION_ID, notification,
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
    ```

### Symptom & Impact
*   When the user taps the mic button on the overlay bar, the overlay sends a `mic_tap` command to the main application process via IPC.
*   Because the main application is backgrounded and the foreground service does not have the active `FOREGROUND_SERVICE_TYPE_MICROPHONE` property, Android blocks the background process from capturing microphone audio.
*   **Result:** The application records silent audio, or throws a `SecurityException` process crash.

---

## 2. Dynamic Resizing Logic Bug (Clipping / Crash)

### Root Cause
*   **Location:** [OverlayService.java (line 427-438)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java#L427-L438) - `resizeOverlay`
*   The logic to update the layout height during dynamic expansion checks for parent matches with:
    ```java
    params.height = (height != 1999 || height != -1) ? dpToPx(height) : height;
    ```
*   Because `||` (OR) is used, the check is always `true`. If `height` is `WindowSize.matchParent` (`-1`) or `WindowSize.fullCover` (`-1999`), it passes the negative value straight to `dpToPx()`, producing an invalid negative pixel value.

### Symptom & Impact
*   Dynamic overlay expansion (e.g., when transitioning to text input or viewing expanded answers) fails or triggers window clipping.

---

## 3. Touch Input Interception in Empty Space

### Root Cause
*   **Location:** [android_overlay_service.dart (line 64-74)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/lib/services/android_overlay_service.dart#L64-L74)
*   The overlay window is requested using `width: WindowSize.matchParent` to support center alignments.
*   This makes the underlying window container span the entire width of the screen, even though the visual AURA pill is a narrow centered element.

### Symptom & Impact
*   All taps occurring to the left or right of the pill (within the vertical bounds of the bar) are captured by the invisible overlay window rather than passing through to background applications.
*   **Result:** Users are blocked from tapping dock icons, launcher items, or system navigation gestures near the bottom corners of the screen.

---

## 4. Soft Keyboard Focus Block

### Root Cause
*   **Location:** [WindowSetup.java (line 37-48)](file:///home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/plugins/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/WindowSetup.java#L37-L48)
*   The overlay is started with `defaultFlag` which maps to `FLAG_NOT_FOCUSABLE`.
*   With `FLAG_NOT_FOCUSABLE` active, the system treats the overlay window as non-interactive for text input. The keyboard will not appear when text fields inside the overlay are tapped.
*   To accept input, the overlay must be dynamically switched to `focusPointer` (`FLAG_NOT_TOUCH_MODAL`), but no dynamic updating of flags on focus change is implemented on the Dart side.

---

## 5. Aggressive OEM Optimization Terminations

### Root Cause
*   Vendor customizations (e.g., Samsung One UI, Xiaomi MIUI) aggressively kill foreground services to optimize battery and memory usage.

### Symptom & Impact
*   Unless the user manually navigates to system settings and sets the AURA app to "Unrestricted" battery usage, the background `OverlayService` is terminated after a few minutes, causing the bar to vanish.
