import 'package:flutter/material.dart';
import 'empty_state.dart';
import 'note_card.dart';
import 'note_dialogs.dart';
import 'stat_chip.dart';

class NotesTabContent extends StatelessWidget {
  final List<Map<String, dynamic>> notes;
  final VoidCallback onLoad;

  const NotesTabContent({
    super.key,
    required this.notes,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final activeNotes = notes.where((n) => n['deleted'] != true).toList();
    final deletedNotes = notes.where((n) => n['deleted'] == true).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              StatChip(
                icon: Icons.sticky_note_2_outlined,
                label: '${activeNotes.length} active',
                color: Colors.indigo.shade400,
              ),
              if (deletedNotes.isNotEmpty) ...[
                const SizedBox(width: 12),
                StatChip(
                  icon: Icons.delete_outline_rounded,
                  label: '${deletedNotes.length} crossed',
                  color: Colors.red.shade400,
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => showAddNoteDialog(context, onLoad),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text(
                  'Add Note',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? const EmptyState(
                  'No notes yet.\nClick "Add Note" to write down important details!',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (activeNotes.isNotEmpty) ...[
                      ...activeNotes.map(
                        (note) => NoteCard(note: note, onLoad: onLoad),
                      ),
                    ],
                    if (deletedNotes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '🗑️ Crossed-out Notes (Can Recover)',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      ...deletedNotes.map(
                        (note) => NoteCard(note: note, onLoad: onLoad),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
