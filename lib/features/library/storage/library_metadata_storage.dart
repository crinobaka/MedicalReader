import 'dart:convert';
import 'dart:io';

import '../models/library_document.dart';

class LibraryMetadataStorage {
  final Directory directory;

  LibraryMetadataStorage({required this.directory});

  File get metadataFile => File('${directory.path}/metadata.json');
  File get backupFile => File('${directory.path}/metadata.json.bak');

  Future<void> _ensureDirectory() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> save(List<LibraryDocument> documents) async {
    await saveJson(documents.map((document) => document.toJson()).toList());
  }

  Future<void> saveJson(List<Map<String, dynamic>> documents) async {
    await _ensureDirectory();
    final payload = jsonEncode(documents);
    final temp = File('${directory.path}/metadata.json.tmp');
    await temp.writeAsString(payload, flush: true);
    try {
      if (await metadataFile.exists()) {
        await metadataFile.copy(backupFile.path);
      }
      await temp.rename(metadataFile.path);
    } catch (_) {
      await temp.delete().catchError((_) {});
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> load() async {
    final primary = await _readJsonFile(metadataFile);
    if (primary != null) return primary;

    final backup = await _readJsonFile(backupFile);
    if (backup != null) {
      try {
        await _ensureDirectory();
        await File('${directory.path}/metadata.json.recovered.tmp')
            .writeAsString(jsonEncode(backup), flush: true)
            .then((file) async => file.rename(metadataFile.path));
      } catch (_) {
        // Recovery itself is best effort; the valid backup is still returned.
      }
    }
    return backup ?? [];
  }

  Future<List<Map<String, dynamic>>?> _readJsonFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is! List) return null;
      final result = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['id'] is String && (item['id'] as String).isNotEmpty)
          .toList(growable: false);
      return result;
    } catch (_) {
      return null;
    }
  }
}
