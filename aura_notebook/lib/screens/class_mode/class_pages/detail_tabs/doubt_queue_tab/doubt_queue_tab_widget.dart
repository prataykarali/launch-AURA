import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../../class_data.dart';
import 'doubt_model.dart';
import 'doubt_card.dart';
import 'empty_state.dart';

const _kSentinel = '\x00__THINKING__\x00';

class DoubtQueueTab extends StatefulWidget {
  final ClassData data;
  const DoubtQueueTab({super.key, required this.data});

  @override
  State<DoubtQueueTab> createState() => _DoubtQueueTabState();
}

class _DoubtQueueTabState extends State<DoubtQueueTab> {
  final List<Doubt> _doubts = [];
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  Timer? _typewriterTimer;
  final List<String> _typewriterQueue = [];
  final StringBuffer _displayedBuffer = StringBuffer();
  bool _generationFinished = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTypewriter(Doubt doubt) {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_typewriterQueue.isNotEmpty) {
        int charsToPop = 1;
        if (_typewriterQueue.length > 80) {
          charsToPop = 4;
        } else if (_typewriterQueue.length > 40) {
          charsToPop = 3;
        } else if (_typewriterQueue.length > 15) {
          charsToPop = 2;
        }

        for (int i = 0;
            i < charsToPop && _typewriterQueue.isNotEmpty;
            i++) {
          _displayedBuffer.write(_typewriterQueue.removeAt(0));
        }

        doubt.streamText.value = '$_displayedBuffer▍';
      } else if (_generationFinished) {
        timer.cancel();
        doubt.streamText.value = _displayedBuffer.toString();
        doubt.isAnswered = true;
        setState(() {});
      }
    });
  }

  Future<void> _postDoubt() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;

    _ctrl.clear();
    _focus.unfocus();
    HapticFeedback.lightImpact();

    final doubt = Doubt(
      question: q,
      subject: widget.data.subject,
      timestamp: DateTime.now(),
    );

    setState(() {
      _doubts.insert(0, doubt);
      _hasText = false;
    });

    await _generateAnswer(doubt);
  }

  Future<void> _generateAnswer(Doubt doubt) async {
    final prompt = 'You are a ${widget.data.subject} teacher. A student asked: '
        '"${doubt.question}"\n\n'
        'Give a clear, helpful answer in 2–3 sentences. Be concise.';

    _displayedBuffer.clear();
    _typewriterQueue.clear();
    _generationFinished = false;
    _startTypewriter(doubt);

    try {
      await for (final token in auraChat(prompt: prompt)) {
        if (!mounted) return;
        if (token == _kSentinel) continue;

        for (final rune in token.runes) {
          _typewriterQueue.add(String.fromCharCode(rune));
        }
      }
    } catch (e) {
      debugPrint('Doubt answer error: $e');
      _generationFinished = true;
      doubt.streamText.value = "Sorry, I couldn't generate an answer right now.";
    }

    _generationFinished = true;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      children: [
        // Top Stats Bar
        Container(
          color: const Color(0xFF0D0D18),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            _statChip(Icons.help_outline_rounded, '${_doubts.length} Doubts', d.accent),
            const SizedBox(width: 10),
            _statChip(Icons.escalator_warning_rounded,
                '${_doubts.where((x) => x.escalated).length} Escalated', Colors.orange),
          ]),
        ),

        // Main List
        Expanded(
          child: _doubts.isEmpty
              ? EmptyState(accent: d.accent)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _doubts.length,
                  itemBuilder: (_, i) => DoubtCard(
                    doubt: _doubts[i],
                    accent: d.accent,
                    color: d.color,
                    onEscalate: () => setState(() {
                      _doubts[i].escalated = true;
                      HapticFeedback.mediumImpact();
                    }),
                    onHelpful: () => setState(() {
                      _doubts[i].markedHelpful = true;
                    }),
                  ),
                ),
        ),

        // Bottom Input Field
        Container(
          color: const Color(0xFF0D0D18),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            top: 8,
          ),
          child: Row(children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E32),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: _hasText
                          ? d.accent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _postDoubt(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ask a doubt…',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.22), fontSize: 13),
                    prefixIcon: Icon(Icons.help_outline_rounded,
                        size: 18, color: d.accent.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _postDoubt,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _hasText
                      ? LinearGradient(
                          colors: [d.color, d.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: !_hasText ? Colors.white.withOpacity(0.08) : null,
                ),
                child: Icon(Icons.send_rounded,
                    color: _hasText
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    size: 18),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}
