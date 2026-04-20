  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:aura_notebook/src/rust/api.dart';
  import '../class_data.dart';

  const _kSentinel = '\x00__THINKING__\x00';

  class DoubtQueueTab extends StatefulWidget {
    final ClassData data;
    const DoubtQueueTab({super.key, required this.data});

    @override
    State<DoubtQueueTab> createState() => _DoubtQueueTabState();
  }

  class _DoubtQueueTabState extends State<DoubtQueueTab> {
    final List<_Doubt> _doubts = [];
    final _ctrl = TextEditingController();
    final _focus = FocusNode();
    bool _hasText = false;

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
      _ctrl.dispose();
      _focus.dispose();
      super.dispose();
    }

    Future<void> _postDoubt() async {
      final q = _ctrl.text.trim();
      if (q.isEmpty) return;

      _ctrl.clear();
      _focus.unfocus();
      HapticFeedback.lightImpact();

      final doubt = _Doubt(
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

    Future<void> _generateAnswer(_Doubt doubt) async {
      final prompt = 'You are a ${widget.data.subject} teacher. A student asked: '
          '"${doubt.question}"\n\n'
          'Give a clear, helpful answer in 2–3 sentences. Be concise.';

      final buf = StringBuffer();
      try {
        // Streaming from your Rust FFI
        await for (final token in auraChat(prompt: prompt)) {
          if (token == _kSentinel) continue;
          buf.write(token);
          doubt.streamText.value = '$buf▍';
        }
      } catch (e) {
        debugPrint('Doubt answer error: $e');
        doubt.streamText.value = "Sorry, I couldn't generate an answer right now.";
      }

      doubt.streamText.value = buf.toString().trim();
      doubt.isAnswered = true;
      if (mounted) setState(() {});
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
                ? _EmptyState(accent: d.accent)
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _doubts.length,
              itemBuilder: (_, i) => _DoubtCard(
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
                      color:
                      _hasText ? Colors.white : Colors.white.withOpacity(0.2),
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

  class _DoubtCard extends StatelessWidget {
    final _Doubt doubt;
    final Color accent, color;
    final VoidCallback onEscalate, onHelpful;

    const _DoubtCard({
      required this.doubt,
      required this.accent,
      required this.color,
      required this.onEscalate,
      required this.onHelpful
    });

    @override
    Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161625),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: doubt.escalated
            ? Colors.orange.withOpacity(0.35)
            : Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.help_rounded, color: accent, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doubt.question,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
              const SizedBox(height: 3),
              Text(_timeAgo(doubt.timestamp),
                  style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 10)),
            ])),
            if (doubt.escalated)
              _badge('Escalated', Colors.orange),
          ]),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.05)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26, height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF40C4FF)]),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: doubt.streamText,
                builder: (_, txt, __) => txt.isEmpty
                    ? _loadingState()
                    : Text(txt, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5)),
              ),
            ),
          ]),
        ),
        if (doubt.isAnswered && !doubt.escalated && !doubt.markedHelpful)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Text('Was this helpful?', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
              const Spacer(),
              _ActionBtn(label: '👍 Yes', color: Colors.greenAccent, onTap: onHelpful),
              const SizedBox(width: 8),
              _ActionBtn(label: '📢 Escalate', color: Colors.orange, onTap: onEscalate),
            ]),
          ),
        if (doubt.markedHelpful)
          _helpfulFooter(),
      ]),
    );

    Widget _badge(String text, Color col) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w700)),
    );

    Widget _loadingState() => Row(children: [
      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: const Color(0xFF7C4DFF).withOpacity(0.6))),
      const SizedBox(width: 8),
      Text('AURA is answering…', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontStyle: FontStyle.italic)),
    ]);

    Widget _helpfulFooter() => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.greenAccent),
        const SizedBox(width: 5),
        Text('Marked helpful', style: TextStyle(color: Colors.greenAccent.withOpacity(0.5), fontSize: 11)),
      ]),
    );

    String _timeAgo(DateTime t) {
      final diff = DateTime.now().difference(t);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
  }

  class _ActionBtn extends StatelessWidget {
    final String label;
    final Color color;
    final VoidCallback onTap;

    const _ActionBtn({
      required this.label,
      required this.color,
      required this.onTap,
      super.key,
    });

    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  class _EmptyState extends StatelessWidget {
    final Color accent;
    const _EmptyState({required this.accent});
    @override
    Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.help_outline_rounded, size: 52, color: accent.withOpacity(0.3)),
        const SizedBox(height: 14),
        const Text('No doubts yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Post a question and AURA will\nanswer it instantly!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, height: 1.5)),
      ]),
    );
  }

  class _Doubt {
    final String question, subject;
    final DateTime timestamp;
    final ValueNotifier<String> streamText = ValueNotifier('');
    bool isAnswered    = false;
    bool escalated     = false;
    bool markedHelpful = false;
    _Doubt({required this.question, required this.subject, required this.timestamp});
  }