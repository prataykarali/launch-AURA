part of '../input_bar.dart';

abstract class _InputBarStateBase extends State<InputBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // _hasText drives send-button visibility. Previously this was a plain bool
  // updated via setState() on EVERY keystroke — on Android that full widget
  // rebuild per keystroke (while the bar overlay + wake-word STT + LLM decode
  // all compete for the single UI isolate) was the direct cause of the
  // "typing in the AURA bar freezes the home screen" jank. A ValueNotifier
  // only notifies listeners when the bool actually flips, so the send button
  // rebuilds at most once per empty↔non-empty transition instead of per key.
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);
  bool _hasText = false;

  // ── Active-typing state ───────────────────────────────────────────────────
  //
  // _isActivelyTyping: true from first keypress until kTypingIdleTimeout of
  // silence. Exposed via the visual pulse on the send button (subtle glow
  // when true) and passed to Rust so Thread A can prioritise live prefills.
  bool _isActivelyTyping = false;
  Timer? _typingIdleTimer;

  // ── Prefill state ─────────────────────────────────────────────────────────
  String _lastPrefilled = '';
  Timer? _prefillTimer;

  // ── STT state ─────────────────────────────────────────────────────────────
  bool _isTranscribing = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    final trimmed = text.trim();

    // Sync _hasText for send-button visibility via the notifier — NOT setState.
    // This is the core fix for the typing freeze: the send button only needs
    // to rebuild when empty↔non-empty flips, not on every keystroke.
    final h = trimmed.isNotEmpty;
    if (h != _hasText) {
      _hasText = h;
      _hasTextNotifier.value = h;
    }

    // ── Update active-typing state ────────────────────────────────────────
    // Any keystroke resets the idle timer and marks typing = true.
    if (trimmed.isNotEmpty) {
      if (!_isActivelyTyping) {
        _isActivelyTyping = true;
        // Typing glow needs a visual update — but only on the active↔idle
        // transition, NOT every keystroke. This setState runs ~once per
        // typing burst, not per character.
        if (mounted) setState(() {});
        debugPrint('TYPING_STATE: active');
        // Pause the wake-word listener while typing so its STT cycle (which
        // competes with the UI isolate + LLM decode on mobile) doesn't fight
        // the keyboard. Mirrors the bar's FocusNode listener in aura_bar.dart.
        // The listener is resumed when typing goes idle (timer below) or on
        // submit/unfocus.
        AuraBarBrain.instance.stopWakeWordListener();
      }
      // Broadcast to AuraBarBrain so proactive triggers are suppressed
      AuraBarBrain.instance.userIsTyping = true;
      AuraBarBrain.instance.lastUserInteraction = DateTime.now();
      _typingIdleTimer?.cancel();
      _typingIdleTimer = Timer(kTypingIdleTimeout, () {
        if (mounted) {
          _isActivelyTyping = false;
          if (mounted) setState(() {});
          AuraBarBrain.instance.userIsTyping = false;
          // Resume the wake-word listener now that typing has gone idle.
          AuraBarBrain.instance.startWakeWordListener();
          debugPrint('TYPING_STATE: idle');
        }
      });
    } else {
      // Input cleared — stop typing immediately
      _typingIdleTimer?.cancel();
      if (_isActivelyTyping) {
        _isActivelyTyping = false;
        if (mounted) setState(() {});
      }
      AuraBarBrain.instance.userIsTyping = false;
      AuraBarBrain.instance.startWakeWordListener();
    }

    // ── Prefill gate + debounce ───────────────────────────────────────────
    // Cancel any pending prefill — user is still typing.
    _prefillTimer?.cancel();

    if (widget.busy.value || trimmed.isEmpty) return;

    // Gate check is cheap (no ML). Run immediately, debounce the Rust call.
    if (!_passesPrefillGate(trimmed, _lastPrefilled)) return;

    _prefillTimer = Timer(kPrefillDebounce, () {
      // Re-check gate inside the timer: user may have changed text.
      final current = _ctrl.text.trim();
      if (!widget.busy.value && _passesPrefillGate(current, _lastPrefilled)) {
        _lastPrefilled = current;
        auraPrefill(partial: current);
        debugPrint(
          'PREFILL_FIRED: ${current.split(RegExp(r"\s+")).length} words, '
          '${current.length} chars, actively_typing=$_isActivelyTyping',
        );
      }
    });
  }

  void _submit({AuraObservationSource source = AuraObservationSource.text}) {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;

    // Reset all typing/prefill state
    _prefillTimer?.cancel();
    _typingIdleTimer?.cancel();
    _lastPrefilled = '';
    final wasTyping = _isActivelyTyping;
    _isActivelyTyping = false;
    if (wasTyping && mounted) setState(() {});
    AuraBarBrain.instance.userIsTyping = false;

    _ctrl.clear();
    _focus.requestFocus();
    widget.onSend(t, source: source);
    // Resume wake-word listening now that the user has submitted.
    AuraBarBrain.instance.startWakeWordListener();
  }

  @override
  void dispose() {
    _prefillTimer?.cancel();
    _typingIdleTimer?.cancel();
    AuraBarBrain.instance.userIsTyping = false;
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }
}
