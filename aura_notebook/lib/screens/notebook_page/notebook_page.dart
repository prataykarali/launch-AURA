import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';
import '../../services/bar_brain.dart';
import '../../services/file_sense_service.dart';
import 'body.dart';
import 'models.dart';

class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key});
  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage>
    with WidgetsBindingObserver {
  List<Turn> _turns = [];
  List<Summary> _summaries = [];
  List<Fact> _facts = [];
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;
  int _activeTab = 0;
  bool _importingFile = false;

  bool _initialLoadDone = false;
  bool _loadInFlight = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialLoadDone) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_loadInFlight) return;
    _loadInFlight = true;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        auraGetAllNotebookTurns(),
        auraGetAllSummariesJson(),
        auraGetAllFactsJson(),
        auraGetMemoryNotesJson(),
      ]);

      final rawTurns = results[0];
      final rawSummaries = results[1];
      final rawFacts = results[2];
      final rawNotes = results[3];

      if (rawTurns.trim().startsWith('ERROR')) {
        throw Exception('Engine busy or no data yet');
      }

      final listTurns = (jsonDecode(rawTurns) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final listSummaries = (jsonDecode(rawSummaries) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final listFacts = (jsonDecode(rawFacts) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final listNotes = (jsonDecode(rawNotes) as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _turns = listTurns.map(Turn.fromJson).toList();
        _summaries = listSummaries.map(Summary.fromJson).toList();
        _facts = listFacts.map(Fact.fromJson).toList();
        _notes = listNotes;
        _loading = false;
        _initialLoadDone = true;
      });

      if (_turns.isEmpty &&
          _summaries.isEmpty &&
          _facts.isEmpty &&
          _notes.isEmpty &&
          !AuraBarBrain.instance.engineReady) {
        _scheduleEngineReadyRetry();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _initialLoadDone = true;
      });
    } finally {
      _loadInFlight = false;
    }
  }

  void _scheduleEngineReadyRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _loadInFlight) return;
      if (AuraBarBrain.instance.engineReady) {
        timer.cancel();
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F4EE),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () {
          auraResetState();
          Navigator.of(context).pop();
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Colors.black87,
          ),
        ),
      ),
      title: Row(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: Colors.indigo.shade300,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "AURA's Notebook",
            style: TextStyle(
              color: Colors.indigo.shade800,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: _importingFile
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          color: Colors.indigo.shade300,
          tooltip: 'Read file into memory',
          onPressed: _importingFile ? null : _importFileIntoMemory,
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.indigo.shade300,
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
    ),
    body: NotebookBody(
      loading: _loading,
      error: _error,
      onLoad: _load,
      activeTab: _activeTab,
      onTabChanged: (i) => setState(() => _activeTab = i),
      turns: _turns,
      summaries: _summaries,
      facts: _facts,
      notes: _notes,
    ),
  );

  Future<void> _importFileIntoMemory() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importingFile = true);
    try {
      final path = await FileSenseService.instance.pickTextFilePath();
      if (path == null || path.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No file selected.')),
        );
        return;
      }
      final ok = await FileSenseService.instance.readFileIntoMemory(path);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'File added to AURA memory.'
                : 'Could not read that file into memory.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importingFile = false);
    }
  }
}
