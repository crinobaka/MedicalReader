import 'dart:convert';
import 'dart:io';

import '../models/library_document.dart';

class LibraryMetadataStorage {
  final Directory directory;

  LibraryMetadataStorage({required this.directory});

  File get metadataFile => File('${directory.path}/metadata.json');

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
    await metadataFile.writeAsString(jsonEncode(documents));
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (!await metadataFile.exists()) return [];

    try {
      final content = await metadataFile.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // metadata 损坏不应该阻止 PDF 库打开。
      return [];
    }
  }
}
