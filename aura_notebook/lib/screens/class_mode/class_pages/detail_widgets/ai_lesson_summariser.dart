import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aura_notebook/src/rust/api.dart';

const _kSentinel = '\x00__THINKING__\x00';

// ─────────────────────────────────────────────────────────────────────────────
// AiLessonSummariser — drop this widget below any lesson tile.
// Pass the lesson title + objectives; it calls auraChat() and streams
// a 3-line student-facing summary directly into the card.
// ─────────────────────────────────────────────────────────────────────────────
class AiLessonSummariser extends StatefulWidget {
  final String lessonTitle;
  final String objectives;
  final Color  accent;

  const AiLessonSummariser({
    super.key,
    required this.lessonTitle,
    required this.objectives,
    required this.accent,
  });

  @override
  State<AiLessonSummariser> createState() => _AiLessonSummariserState();
}

class _AiLessonSummariserState extends State<AiLessonSummariser> {
  final _streamText = ValueNotifier<String>('');
  bool   _loading   = false;
  bool   _done      = false;
  String _finalText = '';

  Future<void> _generate() async {
    if (_loading) return;
    HapticFeedback.lightImpact();
    setState(() { _loading = true; _done = false; _finalText = ''; });
    _streamText.value = '';

    final prompt =
        'You are a helpful teacher. Write a 3-sentence student-friendly summary '
        'of this lesson. Be concise and clear.\n\n'
        'Lesson: ${widget.lessonTitle}\n'
        'Objectives: ${widget.objectives.isEmpty ? "General overview" : widget.objectives}\n\n'
        'Summary:';

    final buf = StringBuffer();
    try {
      await for (final token in auraChat(prompt: prompt)) {
        if (token == _kSentinel) continue;
        buf.write(token);
        _streamText.value = '$buf▍';
      }
    } catch (e) {
      debugPrint('summariser error: $e');
    }

    _finalText = buf.toString().trim();
    _streamText.value = _finalText;
    setState(() { _loading = false; _done = true; });
  }

  void _clear() => setState(() {
    _done = false; _finalText = ''; _streamText.value = '';
  });

  @override
  void dispose() { _streamText.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_done && !_loading) {
      // Show "Generate Summary" button
      return GestureDetector(
        onTap: _generate,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.accent.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded,
                size: 13, color: widget.accent),
            const SizedBox(width: 6),
            Text('Generate AI Summary',
                style: TextStyle(color: widget.accent, fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    // Show streaming / final summary
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Spinning orb while loading
            if (_loading)
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: widget.accent,
                ),
              )
            else
              Icon(Icons.auto_awesome_rounded,
                  size: 12, color: widget.accent),
            const SizedBox(width: 6),
            Text('AURA Summary',
                style: TextStyle(color: widget.accent, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const Spacer(),
            if (_done)
              GestureDetector(
                onTap: _clear,
                child: Icon(Icons.close_rounded, size: 14,
                    color: Colors.white.withOpacity(0.25)),
              ),
          ]),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: _streamText,
            builder: (_, txt, __) => Text(
              txt.isEmpty ? 'Thinking…' : txt,
              style: TextStyle(
                color: txt.isEmpty
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.75),
                fontSize: 12, height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}