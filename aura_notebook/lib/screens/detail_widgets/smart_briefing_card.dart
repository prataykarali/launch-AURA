import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../class_data.dart';

const _kSentinel = '\x00__THINKING__\x00';

// ─────────────────────────────────────────────────────────────────────────────
// SmartBriefingCard
// • Auto-generates a 3-bullet daily class briefing using auraChat()
// • Same streaming pattern as the working AuraSubjectOverlay
// • Collapsible, refresh button, auto-runs on first render
// ─────────────────────────────────────────────────────────────────────────────
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
  Widget _buildErrorState() {
    return Row(
      children: [
        Icon(Icons.error_outline_rounded,
            size: 16, color: Colors.orange.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Could not generate briefing. Tap ↻ to retry.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12),
          ),
        ),
      ],
    );
  }

  // ── Orb animation ──────────────────────────────────────────────────────────
  late final AnimationController _orbCtrl;

  // ── Content state ──────────────────────────────────────────────────────────
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
    // Auto-generate on first open
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _streamText.dispose();
    super.dispose();
  }

  // ── Generate briefing ──────────────────────────────────────────────────────
  // Uses the EXACT same pattern as AuraSubjectOverlay which is confirmed working
  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading  = true;
      _done     = false;
      _hasError = false;
    });
    _streamText.value = '';

    final d   = widget.data;
    final pct = widget.topicsTotal == 0
        ? 0
        : (widget.topicsDone / widget.topicsTotal * 100).toInt();

    // ── FIX: Simple direct prompt, no nested system instructions ──────────────
    // The working overlay uses: 'You are a helpful teacher. Answer clearly: [q]'
    // We follow the exact same pattern.
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
        if (token == _kSentinel) continue;
        buf.write(token);
        // Update the notifier on every token — identical to working overlay
        _streamText.value = '$buf▍';
      }
    } catch (e) {
      debugPrint('SmartBriefingCard error: $e');
      setState(() => _hasError = true);
    }

    // Commit final text
    final finalText = buf.toString().trim();
    _streamText.value = finalText.isEmpty
        ? '• ${d.subject} class is on track.\n• ${widget.topicsDone} topics completed so far.\n• Keep up the great work!'
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
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(),
          // ── Body ────────────────────────────────────────────────────────
          if (_expanded) _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() => GestureDetector(
    onTap: () => setState(() => _expanded = !_expanded),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.09),
        borderRadius: _expanded
            ? const BorderRadius.vertical(top: Radius.circular(18))
            : BorderRadius.circular(18),
        border: Border(
          bottom: _expanded
              ? BorderSide(
              color: const Color(0xFF7C4DFF).withOpacity(0.18))
              : BorderSide.none,
        ),
      ),
      child: Row(children: [
        // Spinning orb
        AnimatedBuilder(
          animation: _orbCtrl,
          builder: (_, __) => Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(
                    _orbCtrl.value * math.pi * 2),
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
        // Refresh
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
        // 1. Loading State (No text yet)
        if (txt.isEmpty && _loading) {
          return _buildLoadingState();
        }

        // 2. Error State
        if (_hasError && txt.isEmpty) {
          return _buildErrorState();
        }

        // 3. Streaming Content State
        final lines = txt
            .replaceAll('▍', '') // Clean the cursor for splitting logic
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: txt.isEmpty ? 0.0 : 1.0, // Smooth fade-in for the first characters
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add the cursor only to the very last line while loading
                  Expanded(
                    child: Text(
                      line + (line == lines.last && _loading ? '▍' : ''),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                          height: 1.5,
                          letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        );
      },
    ),
  );

// Helper for cleaner code
  Widget _buildLoadingState() => Row(children: [
    const SizedBox(
      width: 14, height: 14,
      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C4DFF)),
    ),
    const SizedBox(width: 12),
    Text('AURA is composing...',
        style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12, fontStyle: FontStyle.italic)),
  ]);
}