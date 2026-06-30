import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aura_notebook/src/rust/api/tts.dart' as rust_tts;

// AuraTTSService split into a directory module. Public API unchanged.
part 'online.dart';
part 'engine.dart';

class AuraTTSService {
  AuraTTSService._();
  static final AuraTTSService instance = AuraTTSService._();

  // ── Android platform channel ─────────────────────────────────────────────
  static MethodChannel? _ttsChannel;
  static MethodChannel get _androidTtsChannel {
    _ttsChannel ??= const MethodChannel('aura/tts');
    return _ttsChannel!;
  }

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _useRustTts = false;
  int _activeSpeakCalls = 0;
  bool _playbackSuppressed = false;
  Future<void> _androidSpeakChain = Future<void>.value();

  // TTS anti-spam: skip duplicate text within a short window and reject very
  // short repeated utterances. This prevents the same response from being spoken
  // twice when multiple UI surfaces (chat bubble + AURA bar) both call speak(),
  // and stops runaway rapid chunking from streaming sources.
  String? _lastSpokenText;
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _kTtsDedupWindow = Duration(seconds: 2);
  static const int _kMinSpeakChars = 2;

  AudioPlayer? _onlinePlayer;
  bool _isPlayingOnline = false;
  DateTime? _onlineBackoffUntil;

  AudioPlayer get _getOnlinePlayer {
    _onlinePlayer ??= AudioPlayer();
    return _onlinePlayer!;
  }

  String _lastProvider = 'idle';
  String get lastProvider => _lastProvider;

  void setOnlineVoice(String voiceName) {}

  bool get _canTryOnlineTts {
    final backoffUntil = _onlineBackoffUntil;
    return backoffUntil == null || DateTime.now().isAfter(backoffUntil);
  }

  Timer? _playbackTimer;

  // ── Initialization ─────────────────────────────────────────────────────────
  Completer<void>? _initCompleter;

  Future<void> ensureReady() async {
    if (_initCompleter != null) return _initCompleter!.future;
    return init();
  }

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    debugPrint('AuraTTS: Initializing...');
    try {
      if (Platform.isAndroid) {
        _useRustTts = false;
        _clearMissingDependency();
        try {
          final ready = await _warmupAndroidTts();
          debugPrint('AuraTTS Android: warmup reported ready=$ready');
        } catch (e) {
          debugPrint('AuraTTS Android: warmup error: $e');
        }
        return;
      }

      final ok = await rust_tts.auraTtsInit();
      _useRustTts = ok;
      if (ok) {
        _clearMissingDependency();
        debugPrint('AuraTTS: Rust sherpa-onnx TTS initialized');
        await _syncVolume();
      } else {
        debugPrint('AuraTTS: Rust TTS unavailable');
        if (Platform.isAndroid) {
          try {
            final ready = await _warmupAndroidTts();
            debugPrint('AuraTTS Android: warmup reported ready=$ready');
          } catch (e) {
            debugPrint('AuraTTS Android: warmup error: $e');
          }
        } else {
          _missingDependency = 'sherpa-tts';
          missingDependencyNotifier.value = _missingDependency;
        }
      }
    } catch (e) {
      debugPrint('AuraTTS: init error: $e');
      _useRustTts = false;
      if (Platform.isAndroid) {
        try {
          final ready = await _warmupAndroidTts();
          debugPrint('AuraTTS Android: warmup reported ready=$ready');
        } catch (e2) {
          debugPrint('AuraTTS Android: warmup error: $e2');
        }
      }
    } finally {
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    }
  }

  // ── Missing-dependency surfacing ──────────────────────────────────────────
  String? _missingDependency;
  String? get missingDependency => _missingDependency;
  final ValueNotifier<String?> missingDependencyNotifier =
      ValueNotifier<String?>(null);

  void _clearMissingDependency() {
    if (_missingDependency == null) return;
    _missingDependency = null;
    missingDependencyNotifier.value = null;
  }

  // ── Volume / mute ──────────────────────────────────────────────────────────
  double _volume = 1.0;
  bool _muted = false;
  static const double kMinVolume = 0.0;
  static const double kMaxVolume = 1.0;

  double get volume => _muted ? 0.0 : _volume;
  bool get isMuted => _muted;
  bool get isPlaying =>
      Platform.isAndroid ? (_activeSpeakCalls > 0) : _isPlaying;

  void setPlaybackSuppressed(bool suppressed) {
    if (_playbackSuppressed == suppressed) return;
    _playbackSuppressed = suppressed;
    debugPrint('AuraTTS: playbackSuppressed=$_playbackSuppressed');
    if (suppressed) {
      unawaited(stop());
    }
  }

  void setVolume(double v) {
    final clamped = v.clamp(kMinVolume, kMaxVolume);
    _volume = clamped;
    _muted = clamped <= 0.0;
    debugPrint('AuraTTS: volume=${(_volume * 100).round()}% muted=$_muted');
    if (_onlinePlayer != null && _isPlayingOnline) {
      unawaited(_onlinePlayer!.setVolume(_muted ? 0.0 : _volume));
    }
    unawaited(_syncVolume());
  }

  void toggleMute() {
    _muted = !_muted;
    if (!_muted && _volume <= 0.0) _volume = 1.0;
    debugPrint('AuraTTS: toggleMute → muted=$_muted');

    if (_onlinePlayer != null && _isPlayingOnline) {
      unawaited(_onlinePlayer!.setVolume(_muted ? 0.0 : 1.0));
    }

    if (_muted && Platform.isAndroid && !_isPlayingOnline) {
      unawaited(stop());
    }
    unawaited(_syncVolume());
  }

  void volumeUp() => setVolume((_volume + 0.2).clamp(kMinVolume, kMaxVolume));
  void volumeDown() =>
      setVolume((_volume - 0.2).clamp(kMinVolume, kMaxVolume));

  // ── Speak ─────────────────────────────────────────────────────────────────
  Future<void> speak(
    String text, {
    VoidCallback? onComplete,
    bool interrupt = false,
  }) async {
    final cleanText = _cleanText(text);
    if (cleanText.length < _kMinSpeakChars) {
      onComplete?.call();
      return;
    }

    // Anti-spam: suppress exact repeats within the dedup window.
    if (!interrupt) {
      final now = DateTime.now();
      if (_lastSpokenText == cleanText &&
          now.difference(_lastSpokenAt) < _kTtsDedupWindow) {
        debugPrint('AuraTTS: skipping duplicate speech within dedup window');
        onComplete?.call();
        return;
      }
    }

    await ensureReady();

    if (_muted || _playbackSuppressed) {
      debugPrint(
        'AuraTTS: ${_muted ? 'muted' : 'hidden'} — skipping speech output',
      );
      _isPlaying = false;
      _activeSpeakCalls = 0;
      onComplete?.call();
      return;
    }

    _isPlaying = true;
    _clearMissingDependency();
    _lastSpokenText = cleanText;
    _lastSpokenAt = DateTime.now();

    if (Platform.isAndroid) {
      final speakFuture = _enqueueAndroidSpeak(
        cleanText,
        interrupt,
        onComplete,
        volume: _muted ? 0.0 : 1.0,
      );
      await speakFuture;
      return;
    }

    final preferOnline =
        Platform.environment['AURA_PREFER_ONLINE_TTS'] == '1';

    if (!preferOnline && _useRustTts) {
      _lastProvider = 'offline_rust_tts';
      await _speakRust(cleanText, interrupt, onComplete);
      return;
    }

    if (_canTryOnlineTts) {
      if (await _speakConfiguredOnline(cleanText, interrupt, onComplete)) {
        return;
      }
      if (await _speakGoogleTranslate(cleanText, interrupt, onComplete)) {
        return;
      }
    }

    if (_useRustTts) {
      _lastProvider = 'offline_rust_tts';
      debugPrint('AuraTTS: online TTS unavailable — using offline Rust TTS');
      await _speakRust(cleanText, interrupt, onComplete);
      return;
    }

    _reportMissingOfflineTts(cleanText, onComplete);
  }

  // ── Stop ──────────────────────────────────────────────────────────────────
  Future<void> stop() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    _activeSpeakCalls = 0;
    _androidSpeakChain = Future<void>.value();
    _lastSpokenText = null;
    _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);

    if (_onlinePlayer != null) {
      try {
        await _onlinePlayer!.stop();
      } catch (_) {}
    }
    _isPlayingOnline = false;

    if (_useRustTts) {
      try {
        await rust_tts.auraTtsStop();
      } catch (_) {}
    }
    if (Platform.isAndroid) {
      try {
        await _androidTtsChannel.invokeMethod<bool>('stop');
      } catch (_) {}
    }
  }

  // ── Streaming stubs ───────────────────────────────────────────────────────
  Future<bool> beginStream() async => false;
  Future<void> streamText(String text) async {}
  Future<void> endStream() async {}
}
