import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../class_data.dart';

const _kSentinel = '\x00__THINKING__\x00';

class SmartBriefingCard extends StatefulWidget {
  final ClassData data;
  final int       topicsDone;
  final int       topicsTotal;
  final int       xp;
  final int       studentCount;

  const SmartBriefingCard({
    super.key,
    required this.data,
    required this.topicsDone,
    required this.topicsTotal,
    required this.xp,
    required this.studentCount,
  });

  @override
  State<SmartBriefingCard> createState() => _SmartBriefingCardState();
}

class _SmartBriefingCardState extends State<SmartBriefingCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _orbCtrl;
  final _streamText = ValueNotifier<String>('');
  bool  _loading    = false;
  bool  _done       = false;
  bool  _expanded   = true;
  bool  _hasError   = false;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generate();         // ← guard added
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _streamText.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!mounted) return;              // ← guard
    if (_loading) return;

    if (mounted) setState(() {
      _loading  = true;
      _done     = false;
      _hasError = false;
    });
    _streamText.value = '';

    final d   = widget.data;
    final pct = widget.topicsTotal == 0
        ? 0
        : (widget.topicsDone / widget.topicsTotal * 100).toInt();

    final prompt =
        'You are a helpful teacher for ${d.name} (${d.subject}). '
        'Write a brief daily class update as exactly 3 short bullet points. '
        'Each bullet starts with a relevant emoji and is under 12 words. '
        'Use this class info: syllabus $pct% done '
        '(${widget.topicsDone} of ${widget.topicsTotal} topics), '
        '${widget.studentCount} students enrolled, '
        'teacher is ${d.teacher}, class level XP is ${widget.xp}. '
        'Write the 3 bullets now:';

    final buf = StringBuffer();
    try {
      await for (final token in auraChat(prompt: prompt)) {
        if (!mounted) return;          // ← guard on every token
        if (token == _kSentinel) continue;
        buf.write(token);
        _streamText.value = '$buf▍';
      }
    } catch (e) {
      debugPrint('SmartBriefingCard error: $e');
      if (!mounted) return;            // ← guard
      setState(() => _hasError = true);
    }

    if (!mounted) return;              // ← guard before final setState

    final finalText = buf.toString().trim();
    _streamText.value = finalText.isEmpty
        ? '• ${d.subject} class is on track.\n'
        '• ${widget.topicsDone} topics completed so far.\n'
        '• Keep up the great work!'
        : finalText;

    setState(() { _loading = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF12121F)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        border: Border.all(
            color: const Color(0xFF7C4DFF).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (_expanded) _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() => GestureDetector(
    onTap: () { if (mounted) setState(() => _expanded = !_expanded); },
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.09),
        borderRadius: _expanded
            ? const BorderRadius.vertical(top: Radius.circular(18))
            : BorderRadius.circular(18),
        border: Border(
          bottom: _expanded
              ? BorderSide(color: const Color(0xFF7C4DFF).withOpacity(0.18))
              : BorderSide.none,
        ),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _orbCtrl,
          builder: (_, __) => Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(_orbCtrl.value * math.pi * 2),
                colors: const [
                  Color(0xFF7C4DFF), Color(0xFF40C4FF),
                  Color(0xFF00E5FF), Color(0xFF7C4DFF),
                ],
              ),
              boxShadow: [BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(
                    _loading ? 0.5 : 0.25),
                blurRadius: _loading ? 12 : 6,
              )],
            ),
            child: Icon(
                _loading
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.white, size: 15),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Smart Briefing",
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text('Auto-generated by AURA',
                  style: TextStyle(color: Color(0xFF9C6DFF),
                      fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _generate,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
                _loading
                    ? Icons.hourglass_empty_rounded
                    : Icons.refresh_rounded,
                size: 14,
                color: const Color(0xFF7C4DFF)),
          ),
        ),
        const SizedBox(width: 6),
        Icon(_expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
            size: 18, color: Colors.white.withOpacity(0.35)),
      ]),
    ),
  );

  Widget _buildBody() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: ValueListenableBuilder<String>(
      valueListenable: _streamText,
      builder: (_, txt, __) {
        if (txt.isEmpty && _loading) return _buildLoadingState();
        if (_hasError && txt.isEmpty)  return _buildErrorState();

        final lines = txt
            .replaceAll('▍', '')
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: txt.isEmpty ? 0.0 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                line + (line == lines.last && _loading ? '▍' : ''),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.5,
                    letterSpacing: 0.2),
              ),
            )).toList(),
          ),
        );
      },
    ),
  );

  Widget _buildLoadingState() => Row(children: [
    const SizedBox(
      width: 14, height: 14,
      child: CircularProgressIndicator(
          strokeWidth: 1.5, color: Color(0xFF7C4DFF)),
    ),
    const SizedBox(width: 12),
    Text('AURA is composing...',
        style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12, fontStyle: FontStyle.italic)),
  ]);

  Widget _buildErrorState() => Row(
    children: [
      Icon(Icons.error_outline_rounded,
          size: 16, color: Colors.orange.withOpacity(0.6)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Could not generate briefing. Tap ↻ to retry.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.35), fontSize: 12),
        ),
      ),
    ],
  );
}