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
        final grouped = _groupFacts(facts);
        return Column(
          children: [
            StatsBar(
              mainLabel: '${facts.length} facts mapped',
              dateLabel: formatShort(facts.first.updatedAt),
              dateColor: Colors.teal.shade300,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: grouped.entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.indigo.shade50),
                    ),
                    color: Colors.white,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          entry.key,
                          style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        children: entry.value
                            .map((f) => FactCard(fact: f))
                            .toList(),
                      ),
                    ),
                  );
                }).toList(),
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

  Map<String, List<Fact>> _groupFacts(List<Fact> facts) {
    final Map<String, List<Fact>> groups = {
      '👤 Identity & Info': [],
      '🎨 Preferences & Hobbies': [],
      '💼 Professional & Academic': [],
      '🏥 Health & Lifestyle': [],
      '💡 General Details': [],
    };

    for (final fact in facts) {
      final key = fact.key.toLowerCase();
      if (key == 'name' ||
          key == 'birthday' ||
          key == 'age' ||
          key == 'location' ||
          key == 'origin' ||
          key.contains('live') ||
          key.contains('born')) {
        groups['👤 Identity & Info']!.add(fact);
      } else if (key == 'likes' ||
          key == 'loves' ||
          key == 'hates' ||
          key == 'dislikes' ||
          key == 'enjoys' ||
          key == 'prefers' ||
          key == 'favorite' ||
          key == 'favourite' ||
          key == 'hobby') {
        groups['🎨 Preferences & Hobbies']!.add(fact);
      } else if (key == 'work' ||
          key == 'workplace' ||
          key.contains('stud') ||
          key.contains('job') ||
          key.contains('career')) {
        groups['💼 Professional & Academic']!.add(fact);
      } else if (key == 'allergy' ||
          key == 'diet' ||
          key.contains('health') ||
          key.contains('allerg') ||
          key.contains('asthma') ||
          key.contains('diabetes') ||
          key == 'vegan' ||
          key == 'vegetarian') {
        groups['🏥 Health & Lifestyle']!.add(fact);
      } else {
        groups['💡 General Details']!.add(fact);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }
}
