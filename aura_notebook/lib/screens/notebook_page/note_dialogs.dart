import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart' show auraAddMemoryNote;
import 'package:aura_notebook/src/rust/api/memory.dart' show auraUpdateMemoryNote;

Future<void> showAddNoteDialog(BuildContext context, VoidCallback onLoad) async {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  bool pinned = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              color: Colors.indigo.shade800,
            ),
            const SizedBox(width: 8),
            const Text('Add New Note'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter title (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter note content...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Pin note to top:'),
                  const Spacer(),
                  Switch(
                    value: pinned,
                    onChanged: (v) {
                      setStateDialog(() {
                        pinned = v;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note content cannot be empty.'),
                  ),
                );
                return;
              }
              await auraAddMemoryNote(
                title: title,
                content: content,
                pinned: pinned,
              );
              Navigator.of(ctx).pop();
              onLoad();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showEditNoteDialog(
  BuildContext context,
  Map<String, dynamic> note,
  VoidCallback onLoad,
) async {
  final id = note['id'] as int;
  final titleController = TextEditingController(text: note['title'] ?? '');
  final contentController = TextEditingController(text: note['content'] ?? '');
  bool pinned = note['pinned'] == true;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              color: Colors.indigo.shade800,
            ),
            const SizedBox(width: 8),
            const Text('Edit Note'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter title (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter note content...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Pin note to top:'),
                  const Spacer(),
                  Switch(
                    value: pinned,
                    onChanged: (v) {
                      setStateDialog(() {
                        pinned = v;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note content cannot be empty.'),
                  ),
                );
                return;
              }
              await auraUpdateMemoryNote(
                id: id,
                title: title,
                content: content,
                pinned: pinned,
                deleted: false,
              );
              Navigator.of(ctx).pop();
              onLoad();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
