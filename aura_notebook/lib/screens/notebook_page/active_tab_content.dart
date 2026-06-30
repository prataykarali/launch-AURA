import 'package:flutter/material.dart';
import 'cards.dart';
import 'date_helpers.dart';
import 'empty_state.dart';
import 'models.dart';
import 'notes_tab.dart';
import 'stats_bar.dart';

class ActiveTabContent extends StatelessWidget {
  final int activeTab;
  final List<Turn> turns;
  final List<Summary> summaries;
  final List<Fact> facts;
  final List<Map<String, dynamic>> notes;
  final VoidCallback onLoad;

  const ActiveTabContent({
    super.key,
    required this.activeTab,
    required this.turns,
    required this.summaries,
    required this.facts,
    required this.notes,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    switch (activeTab) {
      case 0:
        if (turns.isEmpty) {
          return const EmptyState(
            'No conversations yet.\nSay something to AURA!',
          );
        }
        return Column(
          children: [
            StatsBar(
              mainLabel: '${turns.length} turns',
              dateLabel: formatShort(turns.first.ts),
              dateColor: Colors.teal.shade300,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: turns.length,
                itemBuilder: (_, i) =>
                    TurnCard(turn: turns[i], index: turns.length - i),
              ),
            ),
          ],
        );
      case 1:
        if (summaries.isEmpty) {
          return const EmptyState(
            'No topic summaries yet.\nAURA creates summaries when topics shift.',
          );
        }
        return Column(
          children: [
            StatsBar(
              mainLabel: '${summaries.length} topics',
              dateLabel: formatShort(summaries.first.createdAt),
              dateColor: Colors.purple.shade300,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: summaries.length,
                itemBuilder: (_, i) => SummaryCard(summary: summaries[i]),
              ),
            ),
          ],
        );
      case 2:
        if (facts.isEmpty) {
          return const EmptyState(
            'No personal facts found.\nTalk to AURA to build your profile!',
          );
        }
        return Column(
          children: [
            StatsBar(
              mainLabel: '${facts.length} facts',
              dateLabel: formatShort(facts.first.updatedAt),
              dateColor: Colors.teal.shade300,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: facts.length,
                itemBuilder: (_, i) => FactCard(fact: facts[i]),
              ),
            ),
          ],
        );
      case 3:
        return NotesTabContent(notes: notes, onLoad: onLoad);
      default:
        return const SizedBox.shrink();
    }
  }
}
