import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bar_window_app_host.dart';

class _QueuedMessage {
  final String method;
  final dynamic arguments;
  _QueuedMessage(this.method, this.arguments);
}

class BarWindowAppIpc {
  final BarWindowAppHost _host;

  BarWindowAppIpc(this._host);

  static const MethodChannel _barWindowChannel = MethodChannel(
    'aura/bar_window',
  );

  /// Cached main window ID — discovered once via WindowController.getAll().
  /// On Linux, desktop_multi_window assigns a random UUID to each window
  /// (e.g. "80e80b16-1b4e-…"), NOT the naive "0" that was hardcoded before.
  /// That stale "0" caused every bar→main IPC call to fail with
  /// CHANNEL_UNREGISTERED, making ALL bar buttons (mic, speaker, volume,
  /// text submit) silently unresponsive while the engine itself worked fine.
  String? _mainWindowId;

  /// Message queue for failed IPC calls. When the main window is busy
  /// (e.g. during LLM generation), messages are buffered here and retried.
  /// This fixes the issue where bar drops messages after 2-3 inputs.
  final List<_QueuedMessage> _messageQueue = [];
  static const int _maxQueueSize = 30;
  Timer? _queueDrainTimer;
  bool _isDraining = false;

  // ── Drag state with threshold ──────────────────────────────────────────
  // We track the pointer position ourselves instead of relying on Flutter's
  // gesture arena. A drag is only initiated once the pointer moves ≥ 25 px
  // from its start position. This prevents micro-movements during button taps
  // from firing begin_drag / update_drag on the native side, which was the
  // primary cause of the bar "dancing" on every tap. 25px is well above the
  // ~10px of incidental finger/pixel jitter on a button press but still small
  // enough that a deliberate drag registers within the first ~50ms of motion.
  static const double _dragThreshold = 25.0;
  Offset? _dragStartPos;
  bool _dragActive = false;

  /// Discover the main window's real ID by listing all windows and excluding
  /// this bar window. The main window is the one that is NOT us.
  Future<String?> _discoverMainWindowId() async {
    try {
      final windows = await WindowController.getAll();
      final myId = _host.controller?.windowId;
      for (final w in windows) {
        if (w.windowId != myId) {
          debugPrint('BarWindow: discovered main window id=${w.windowId}');
          return w.windowId;
        }
      }
    } catch (e) {
      debugPrint('BarWindow: failed to discover main window: $e');
    }
    return null;
  }

  /// Forward an action to the MAIN window, which owns the engine + the single
  /// ready AuraBarBrain instance. The bar runs as a separate desktop_multi_window
  /// child isolate; calling AuraBarBrain here would use a DIFFERENT instance
  /// whose `engineReady` is never set true (only the main window sets it on
  /// auraInit completion) → submitted text/prompts would be queued forever
  /// ("Just waking up…") and never processed. Routing via IPC mirrors how the
  /// Android overlay already works (see main.dart handlers: mic_tap /
  /// speaker_tap / volume_tap / submit_text).
  ///
  /// RETRY + QUEUE: If the IPC call fails, retry up to 5 times with exponential
  /// backoff. If all retries fail, buffer the message and drain later. This
  /// fixes the issue where the bar drops messages after 2-3 inputs (Issue #1).
  Future<void> invokeMain(String method, [dynamic arguments]) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (_mainWindowId == null) {
          _mainWindowId = await _discoverMainWindowId();
        }
        if (_mainWindowId == null) {
          debugPrint(
            'BarWindow: IPC "$method" skipped — main window not found',
          );
          _enqueueMessage(method, arguments);
          return;
        }
        await WindowController.fromWindowId(
          _mainWindowId!,
        ).invokeMethod(method, arguments);
        // Success — trigger drain of any queued messages.
        _startQueueDrain();
        return;
      } catch (e) {
        _mainWindowId = null;
        if (attempt < 4) {
          debugPrint(
            'BarWindow: IPC "$method" attempt ${attempt + 1} failed: $e — retrying',
          );
          await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        } else {
          debugPrint(
            'BarWindow: IPC "$method" to main failed after 5 attempts: $e — queuing',
          );
          _enqueueMessage(method, arguments);
        }
      }
    }
  }

  void _enqueueMessage(String method, dynamic arguments) {
    if (_messageQueue.length >= _maxQueueSize) {
      _messageQueue.removeAt(0); // Drop oldest.
      debugPrint('BarWindow: message queue full, dropped oldest');
    }
    _messageQueue.add(_QueuedMessage(method, arguments));
    debugPrint('BarWindow: queued "$method" (${_messageQueue.length} pending)');
    _startQueueDrain();
  }

  void _startQueueDrain() {
    // Don't restart the timer if one is already running or drain is active.
    if (_isDraining ||
        (_queueDrainTimer != null && _queueDrainTimer!.isActive)) {
      return;
    }
    _queueDrainTimer = Timer(const Duration(seconds: 2), _drainQueue);
  }

  Future<void> _drainQueue() async {
    if (_messageQueue.isEmpty || _isDraining) return;
    _isDraining = true;
    try {
      while (_messageQueue.isNotEmpty) {
        final msg = _messageQueue.removeAt(0);
        debugPrint(
          'BarWindow: draining queued "${msg.method}" (${_messageQueue.length} remaining)',
        );
        await invokeMain(msg.method, msg.arguments);
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> notifyMainClosing() async {
    try {
      _mainWindowId ??= await _discoverMainWindowId();
      if (_mainWindowId == null) return;
      await WindowController.fromWindowId(
        _mainWindowId!,
      ).invokeMethod('sub_window_closed');
    } catch (_) {}
  }

  Future<void> resize(int width, int height) async {
    if (Platform.isLinux) {
      try {
        await _barWindowChannel.invokeMethod<void>('resize_bar', {
          'width': width,
          'height': height,
        });
      } catch (_) {}
    }
  }

  // ── Drag handling with dead-zone threshold ─────────────────────────────
  // Only initiates a native drag after the pointer has moved ≥ 10 px from
  // its start position. This prevents tiny finger tremors during button taps
  // from calling gtk_window_move and making the bar jitter.

  void onPointerDown(PointerDownEvent e) {
    _dragStartPos = e.position;
    _dragActive = false;
  }

  void onPointerMove(PointerMoveEvent e) {
    if (_dragStartPos == null) return;
    final d = (e.position - _dragStartPos!).distance;
    if (!_dragActive) {
      if (d >= _dragThreshold && Platform.isLinux) {
        _dragActive = true;
        _beginDrag();
      }
    } else if (Platform.isLinux) {
      _updateDrag();
    }
  }

  void onPointerUp(PointerUpEvent e) {
    if (_dragActive && Platform.isLinux) {
      _endDrag();
    }
    _dragStartPos = null;
    _dragActive = false;
  }

  void onPointerCancel(PointerCancelEvent e) {
    if (_dragActive && Platform.isLinux) {
      _endDrag();
    }
    _dragStartPos = null;
    _dragActive = false;
  }

  Future<void> _beginDrag() async {
    try {
      await _barWindowChannel.invokeMethod<void>('begin_drag');
    } catch (_) {
      // Drag is a convenience; ignore transient native-channel misses.
    }
  }

  Future<void> _updateDrag() async {
    try {
      await _barWindowChannel.invokeMethod<void>('update_drag');
    } catch (_) {}
  }

  Future<void> _endDrag() async {
    try {
      await _barWindowChannel.invokeMethod<void>('end_drag');
    } catch (_) {}
  }
}
