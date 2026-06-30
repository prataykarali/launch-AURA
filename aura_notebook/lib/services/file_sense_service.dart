import 'dart:io';

import 'package:flutter/foundation.dart';

import '../src/rust/api/file_read.dart';

class FileSenseService {
  FileSenseService._();
  static final FileSenseService instance = FileSenseService._();

  Future<String?> pickTextFilePath() async {
    if (Platform.isLinux) {
      return _pickLinuxFile();
    }
    return null;
  }

  Future<bool> readFileIntoMemory(String path, {String? label}) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return false;
    final sourceLabel = label?.trim().isNotEmpty == true
        ? label!.trim()
        : _basename(trimmed);
    try {
      return await auraReadFileIntoMemory(path: trimmed, label: sourceLabel);
    } catch (e) {
      debugPrint('[AURA_FILE_SENSE] Dart call failed: $e');
      return false;
    }
  }

  Future<String?> _pickLinuxFile() async {
    final commands = <List<String>>[
      ['zenity', '--file-selection'],
      ['kdialog', '--getopenfilename', '.'],
      ['yad', '--file-selection'],
    ];

    for (final command in commands) {
      try {
        final result = await Process.run(
          command.first,
          command.skip(1).toList(),
        ).timeout(const Duration(seconds: 30));
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty && await File(path).exists()) return path;
        }
      } catch (_) {
        // Try the next chooser.
      }
    }
    return null;
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.substring(slash + 1) : normalized;
  }
}
