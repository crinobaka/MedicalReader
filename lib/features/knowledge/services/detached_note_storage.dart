import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/note_document.dart';

/// Stores notes that have deliberately been detached from a source book.
class DetachedNoteStorage {
  const DetachedNoteStorage();

  static const _directoryName = 'detached_notes';

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}$_directoryName');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> save(NoteDocument note) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}${_safeId(note.id)}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(note.toJson()));
  }

  Future<List<NoteDocument>> loadAll() async {
    final directory = await _directory();
    final result = <NoteDocument>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map<String, dynamic>) result.add(NoteDocument.fromJson(decoded));
      } catch (_) {
        // One damaged detached note must not prevent other notes from loading.
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<void> delete(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}${_safeId(id)}.json');
    if (await file.exists()) await file.delete();
  }

  String _safeId(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
