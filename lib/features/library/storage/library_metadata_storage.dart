import 'dart:convert';
import 'dart:io';

import '../models/library_document.dart';

class LibraryMetadataStorage {
  final Directory directory;

  LibraryMetadataStorage({
    required this.directory,
  });

  File get metadataFile {
    return File(
      '${directory.path}/metadata.json',
    );
  }

  Future<void> _ensureDirectory() async {
    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }
  }

  Future<void> save(
    List<LibraryDocument> documents,
  ) async {
    await _ensureDirectory();

    final jsonList = documents
        .map(
          (document) => document.toJson(),
        )
        .toList();

    await metadataFile.writeAsString(
      jsonEncode(jsonList),
    );
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (!await metadataFile.exists()) {
      return [];
    }

    final content = await metadataFile.readAsString();

    final decoded = jsonDecode(content);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }
}