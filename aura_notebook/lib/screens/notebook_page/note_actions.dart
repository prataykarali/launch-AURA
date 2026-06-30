import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart' show auraDeleteMemoryNote;
import 'package:aura_notebook/src/rust/api/memory.dart' show auraUpdateMemoryNote, auraRecoverMemoryNote, auraDeleteMemoryNotePermanently;

Future<void> togglePinNote(Map<String, dynamic> note, VoidCallback onLoad) async {
  final id = note['id'] as int;
  final title = note['title'] ?? '';
  final content = note['content'] ?? '';
  final pinned = note['pinned'] == true;

  await auraUpdateMemoryNote(
    id: id,
    title: title,
    content: content,
    pinned: !pinned,
    deleted: false,
  );
  onLoad();
}

Future<void> deleteNote(int id, VoidCallback onLoad) async {
  await auraDeleteMemoryNote(id: id);
  onLoad();
}

Future<void> recoverNote(int id, VoidCallback onLoad) async {
  await auraRecoverMemoryNote(id: id);
  onLoad();
}

Future<void> deletePermanently(
  BuildContext context,
  int id,
  VoidCallback onLoad,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Permanently?'),
      content: const Text(
        'This action cannot be undone. Do you want to purge this note?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await auraDeleteMemoryNotePermanently(id: id);
    onLoad();
  }
}
