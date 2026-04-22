import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';

// ── DATE HELPERS ──────────────────────────────────────────────────────────────
String _fmtShort(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

String _fmtFull(DateTime dt) {
  const days   = ['Monday','Tuesday','Wednesday','Thursday',
    'Friday','Saturday','Sunday'];
  const months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];
  final hh = dt.hour.toString().padLeft(2,'0');
  final mm = dt.minute.toString().padLeft(2,'0');
  final ss = dt.second.toString().padLeft(2,'0');
  return '${days[dt.weekday-1]}, ${months[dt.month-1]} ${dt.day} ${dt.year} • $hh:$mm:$ss';
}

// ── DATA CLASS ────────────────────────────────────────────────────────────────
class _Turn {
  final String   user;
  final String   aura;
  final DateTime ts;
  const _Turn({required this.user, required this.aura, required this.ts});

  factory _Turn.fromJson(Map<String, dynamic> j) => _Turn(
    user: j['user'] as String? ?? '',
    aura: j['aura'] as String? ?? '',
    ts:   DateTime.fromMillisecondsSinceEpoch(
        ((j['ts'] as num?) ?? 0).toInt() * 1000),
  );
}

// ── PAGE ──────────────────────────────────────────────────────────────────────
class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key});
  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> with WidgetsBindingObserver {
  List<_Turn> _turns   = [];
  bool        _loading = true;
  String?     _error;

  // ╔══════════════════════════════════════════════════════════════════════╗
  // ║  ROOT CAUSE FIX #3 — NOTEBOOK NOT WORKING                          ║
  // ║  didChangeDependencies() fires on EVERY inherited widget change:    ║
  // ║  scroll position, MediaQuery, Theme, Navigator, etc.               ║
  // ║  Original guard: `if (!_loading && _error == null) _load()`        ║
  // ║  Problem: after initState sets _loading=true and fires _load(),     ║
  // ║  didChangeDependencies fires (it always does after initState),      ║
  // ║  sees _loading=true, skips. But _load() sets _loading=false when   ║
  // ║  done, then NEXT inherited change (e.g. keyboard inset) triggers    ║
  // ║  didChangeDependencies again → _load() called again → infinite      ║
  // ║  loop of API calls. On slow devices this manifests as blank screen  ║
  // ║  or spinner that never resolves.                                    ║
  // ║                                                                     ║
  // ║  FIX: Track whether the initial load has completed with a bool      ║
  // ║  flag. didChangeDependencies only triggers a reload on foreground   ║
  // ║  resume (via didChangeAppLifecycleState), never on dependency       ║
  // ║  changes. Remove the didChangeDependencies reload entirely —        ║
  // ║  it was the wrong hook for this. Use RouteObserver pattern or       ║
  // ║  willPopScope if reload-on-return is needed.                        ║
  // ╚══════════════════════════════════════════════════════════════════════╝
  bool _initialLoadDone = false;
  // Prevents concurrent _load() calls from the Timer/resume path
  bool _loadInFlight    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FIX: reload ONLY on foreground resume, not on every dependency change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialLoadDone) {
      _load();
    }
  }

  // FIX: didChangeDependencies removed — it was causing the infinite reload.
  // If you need reload-on-navigate-back, use a RouteObserver subscription
  // or call _load() explicitly from the Navigator.push().then() callback
  // at the call site in home.dart.

  Future<void> _load() async {
    if (!mounted) return;
    // Guard against concurrent loads
    if (_loadInFlight) return;
    _loadInFlight = true;

    setState(() { _loading = true; _error = null; });
    try {
      final raw  = await auraGetAllNotebookTurns();
      final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String,dynamic>>();
      if (!mounted) return;
      setState(() {
        _turns            = list.map(_Turn.fromJson).toList();
        _loading          = false;
        _initialLoadDone  = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading         = false;
        _error           = e.toString();
        _initialLoadDone = true;
      });
    } finally {
      _loadInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F4EE),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 6, offset: const Offset(0,2))],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size:16, color:Colors.black87),
        ),
      ),
      title: Row(children: [
        Icon(Icons.auto_stories_rounded, color: Colors.indigo.shade300, size:20),
        const SizedBox(width:8),
        Text("AURA's Notebook", style: TextStyle(
            color: Colors.indigo.shade800, fontSize:18,
            fontWeight: FontWeight.w600, letterSpacing:0.2)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.indigo.shade300,
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
    ),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: Colors.indigo.shade300, strokeWidth: 2),
        const SizedBox(height:14),
        Text('Reading notebook…',
            style: TextStyle(color: Colors.indigo.shade300, fontSize:13)),
      ]));
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size:40),
          const SizedBox(height:12),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade400, fontSize:13)),
          const SizedBox(height:16),
          TextButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      ));
    }

    if (_turns.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.book_outlined, color: Colors.indigo.shade100, size:48),
        const SizedBox(height:12),
        Text('No conversations yet.\nSay something to AURA!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.indigo.shade300, fontSize:14,
                height:1.5, fontStyle: FontStyle.italic)),
      ]));
    }

    return Column(children: [
      // Stats bar
      Container(
        margin:  const EdgeInsets.fromLTRB(16,0,16,12),
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.indigo.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0,3))],
        ),
        child: Row(children: [
          _StatChip(icon: Icons.chat_bubble_outline_rounded,
              label: '${_turns.length} turns', color: Colors.indigo.shade300),
          const SizedBox(width:12),
          _StatChip(icon: Icons.calendar_today_outlined,
              label: _fmtShort(_turns.first.ts), color: Colors.teal.shade300),
          const Spacer(),
          Text('Sled DB ✓', style: TextStyle(
              color: Colors.green.shade400, fontSize:11, fontWeight:FontWeight.w500)),
        ]),
      ),
      // Turn list
      Expanded(
        child: ListView.builder(
          padding:     const EdgeInsets.fromLTRB(16,0,16,24),
          itemCount:   _turns.length,
          itemBuilder: (_, i) => _TurnCard(turn: _turns[i], index: i+1),
        ),
      ),
    ]);
  }
}

// ── TURN CARD ─────────────────────────────────────────────────────────────────
class _TurnCard extends StatelessWidget {
  final _Turn turn;
  final int   index;
  const _TurnCard({super.key, required this.turn, required this.index});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom:12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.indigo.withOpacity(0.06),
          blurRadius: 10, offset: const Offset(0,3))],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding:     const EdgeInsets.symmetric(horizontal:16, vertical:4),
        childrenPadding: const EdgeInsets.fromLTRB(16,0,16,14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width:30, height:30,
          decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
          child: Center(child: Text('$index', style: TextStyle(
              color: Colors.indigo.shade400, fontSize:12, fontWeight:FontWeight.w600))),
        ),
        title: Text(turn.user,
            maxLines:1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:Colors.black87)),
        subtitle: Text('${_fmtShort(turn.ts)}, ${_fmtTime(turn.ts)}',
            style: TextStyle(fontSize:11, color:Colors.grey.shade400)),
        children: [
          _ChatBubble(text: turn.user, isUser: true),
          const SizedBox(height:8),
          _ChatBubble(text: turn.aura, isUser: false),
          const SizedBox(height:8),
          Text(_fmtFull(turn.ts),
              style: TextStyle(fontSize:10, color:Colors.grey.shade400)),
        ],
      ),
    ),
  );
}

// ── CHAT BUBBLE ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool   isUser;
  const _ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal:14, vertical:10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isUser ? Colors.indigoAccent : Colors.indigo.shade50,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(16),
          topRight:    const Radius.circular(16),
          bottomLeft:  Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Text(text, style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize:13, height:1.45)),
    ),
  );
}

// ── STAT CHIP ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatChip({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size:13, color:color),
    const SizedBox(width:4),
    Text(label, style: TextStyle(fontSize:12, color:color, fontWeight:FontWeight.w500)),
  ]);
}