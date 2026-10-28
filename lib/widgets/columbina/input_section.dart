part of '../columbina.dart';

// ── THINKING DOTS ─────────────────────────────────────────────────────────────
class _Thinking extends StatelessWidget {
  final ValueNotifier<bool> thinking;
  const _Thinking({required this.thinking});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: thinking,
    builder: (_, on, __) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: on
          ? Padding(
        key: const ValueKey('on'),
        padding: const EdgeInsets.only(left: 24, bottom: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(),
              const SizedBox(width: 8),
              Text(
                'AURA is thinking…',
                style: TextStyle(
                  color:     Colors.indigo.shade300,
                  fontSize:  12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      )
          : const SizedBox.shrink(key: ValueKey('off')),
    ),
  );
}

class _Dots extends StatefulWidget {
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final p = ((_ac.value * 3) - i).clamp(0.0, 1.0);
        final o = (p < 0.5 ? p * 2 : (1 - p) * 2).clamp(0.3, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4, height: 4,
          decoration: BoxDecoration(
            color: Colors.indigo.shade300.withOpacity(o),
            shape: BoxShape.circle,
          ),
        );
      }),
    ),
  );
}

// ── INPUT BAR ─────────────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final ValueNotifier<bool>           busy;
  const _InputBar({required this.onSend, required this.busy});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool  _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    _focus.requestFocus();
    widget.onSend(t);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.busy,
    builder: (_, isBusy, __) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(
            color:      Colors.indigo.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller:        _ctrl,
                focusNode:         _focus,
                onSubmitted:       (_) => isBusy ? null : _submit(),
                textInputAction:   TextInputAction.send,
                enableSuggestions: false,
                autocorrect:       false,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  hintText:       'Talk to AURA...',
                  hintStyle:      TextStyle(color: Colors.black38, fontSize: 15),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: isBusy ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_hasText && !isBusy)
                        ? Colors.indigoAccent
                        : Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: (_hasText && !isBusy)
                        ? Colors.white
                        : Colors.indigo.shade300,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
