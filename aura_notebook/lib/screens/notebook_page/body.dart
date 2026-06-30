import 'package:flutter/material.dart';
import 'active_tab_content.dart';
import 'models.dart';
import 'tab_selector.dart';

class NotebookBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onLoad;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final List<Turn> turns;
  final List<Summary> summaries;
  final List<Fact> facts;
  final List<Map<String, dynamic>> notes;

  const NotebookBody({
    super.key,
    required this.loading,
    required this.error,
    required this.onLoad,
    required this.activeTab,
    required this.onTabChanged,
    required this.turns,
    required this.summaries,
    required this.facts,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.indigo.shade300,
              strokeWidth: 2,
            ),
            const SizedBox(height: 14),
            Text(
              'Reading notebook…',
              style: TextStyle(color: Colors.indigo.shade300, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade300,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        TabSelector(activeTab: activeTab, onTabChanged: onTabChanged),
        Expanded(
          child: ActiveTabContent(
            activeTab: activeTab,
            turns: turns,
            summaries: summaries,
            facts: facts,
            notes: notes,
            onLoad: onLoad,
          ),
        ),
      ],
    );
  }
}
