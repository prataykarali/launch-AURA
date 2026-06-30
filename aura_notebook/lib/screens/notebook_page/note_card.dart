import 'package:flutter/material.dart';
import 'date_helpers.dart';
import 'note_actions.dart';
import 'note_dialogs.dart';

class NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onLoad;

  const NoteCard({super.key, required this.note, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    final bool isDeleted = note['deleted'] == true;
    final bool isPinned = note['pinned'] == true;
    final int id = note['id'] as int;
    final String title = note['title'] ?? '';
    final String content = note['content'] ?? '';
    final int ts = note['timestamp'] ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDeleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isDeleted
            ? Border.all(color: Colors.red.shade100.withOpacity(0.5))
            : isPinned
                ? Border.all(color: Colors.indigo.shade200, width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned && !isDeleted) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    color: Colors.indigo.shade600,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : 'Untitled Note',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDeleted
                          ? Colors.grey.shade500
                          : Colors.indigo.shade900,
                      decoration: isDeleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                Text(
                  formatShort(date),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: isDeleted ? Colors.grey.shade400 : Colors.black87,
                height: 1.45,
                decoration: isDeleted ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isDeleted) ...[
                  TextButton.icon(
                    onPressed: () => recoverNote(id, onLoad),
                    icon: Icon(
                      Icons.restore_from_trash_rounded,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    label: Text(
                      'Recover',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => deletePermanently(context, id, onLoad),
                    icon: Icon(
                      Icons.delete_forever_rounded,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    label: Text(
                      'Delete Permanently',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () => togglePinNote(note, onLoad),
                    icon: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 16,
                      color: isPinned
                          ? Colors.indigo.shade600
                          : Colors.grey.shade400,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: isPinned ? 'Unpin Note' : 'Pin Note',
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    onPressed: () => showEditNoteDialog(context, note, onLoad),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.indigo.shade400,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit Note',
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    onPressed: () => deleteNote(id, onLoad),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Note',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
