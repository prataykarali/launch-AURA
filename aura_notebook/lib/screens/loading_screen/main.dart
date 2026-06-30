import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aura_notebook/utils/path_manager.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'package:aura_notebook/src/rust/frb_generated.dart';
import 'package:aura_notebook/services/android_overlay_service.dart';
import 'package:aura_notebook/services/stt_service.dart';
import 'package:aura_notebook/services/tts_service.dart';
import 'package:aura_notebook/utils/responsive.dart';
import 'package:aura_notebook/services/bar_brain.dart';
import 'package:path_provider/path_provider.dart';

part 'constants.dart';
part 'file_helpers.dart';
part 'animation_logic.dart';
part 'download_logic.dart';
part 'desktop_logic.dart';
part 'android_logic.dart';
part 'ios_logic.dart';
part 'readiness_logic.dart';
part 'loading_sequence.dart';
part 'state_helpers.dart';
part 'progress_bar.dart';
part 'error_card.dart';

class LoadingScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const LoadingScreen({super.key, this.onDone});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _quoteCtrl;
  late final Animation<double> _quoteFade;

  final Random _random = Random();
  late List<String> _shuffledQuotes;

  _Step _currentStep = _Step.wake;
  String? _errorMsg;
  double? _downloadProgress;
  bool _loadingLock = false;
  int _quoteIndex = 0;
  double _progressTarget = 0.02;

  // ── Warmup creep ──────────────────────────────────────────────────────────
  // The _Step.engine phase now reflects the *real* model-load + system-prompt
  // prefill (auraInit blocks until the Rust worker signals ready). To avoid a
  // frozen 90% bar during that multi-second spin-up, we creep the displayed
  // progress toward (but never past) 0.99 so the bar always feels alive, then
  // snap to 1.0 the instant the engine is actually ready.
  Timer? _creepTimer;
  double _creepValue = 0.90;
  bool _creeping = false;

  static const _stepProgress = {
    _Step.wake: 0.10,
    _Step.check: 0.25,
    _Step.prepare: 0.45,
    _Step.download: 0.65,
    _Step.embed: 0.80,
    _Step.engine: 0.90,
    _Step.services: 0.96,
    _Step.ready: 1.00,
  };

  static const _kStepLabels = {
    _Step.wake: 'AURA is waking up... 🌙',
    _Step.check: 'Checking what I remember... 💭',
    _Step.prepare: 'Getting my thoughts together... ✨',
    _Step.download: 'Downloading...',
    _Step.embed: 'Loading memory... 🧠',
    _Step.engine: 'Almost there, warming up... 🔥',
    _Step.services: 'Starting voice and platform services... 🎙️',
    _Step.ready: 'Ready! 💖',
  };

  /// Safe setState wrapper used by extension methods so they don't trigger
  /// invalid_use_of_protected_member warnings while still keeping state fields
  /// private to this library.
  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _shuffledQuotes = List.of(_kQuotes)..shuffle(_random);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _quoteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
    _quoteFade = CurvedAnimation(parent: _quoteCtrl, curve: Curves.easeIn);
    // Call _load() directly — no artificial delay. When all files are already
    // present on disk the sequence jumps from _Step.check straight to
    // _Step.engine (zero networking or copying), so the loading screen is
    // effectively instant on repeat launches. Using addPostFrameCallback was
    // adding a full render-frame of unnecessary latency before any work began.
    _load();
  }

  @override
  void dispose() {
    _stopWarmupCreep();
    _shimmerCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cycleQuote,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'Assets/images/AURA_load.png',
                fit: R.isDesktop ? BoxFit.fitWidth : BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: R.maxWidth(
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    60,
                  ), // Lowered from 130
                  child: _errorMsg != null
                      ? _ErrorCard(
                          message: _errorMsg!,
                          onRetry: () {
                            setState(() => _errorMsg = null);
                            _loadingLock = false;
                            _load();
                          },
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FadeTransition(
                              opacity: _quoteFade,
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFFF9CEE),
                                        Color(0xFFD5A3FF),
                                        Color(0xFF90F0DF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                child: Text(
                                  _shuffledQuotes[_quoteIndex],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 10,
                                        offset: Offset(2, 2),
                                      ),
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 20,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: _effectiveProgress,
                              ),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOut,
                              builder: (_, value, __) => _ProgressBar(
                                progress: value,
                                shimmerCtrl: _shimmerCtrl,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                ),
                max: 600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
