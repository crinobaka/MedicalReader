import 'dart:convert';
import 'dart:io';

import '../models/library_collection.dart';

class LibraryCollectionsStorage {
  final Directory directory;

  LibraryCollectionsStorage({required this.directory});

  File get collectionsFile => File('${directory.path}/collections.json');

  Future<List<LibraryCollection>> load() async {
    if (!await collectionsFile.exists()) return [];
    try {
      final content = await collectionsFile.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => LibraryCollection.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<LibraryCollection> collections) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    await collectionsFile.writeAsString(jsonEncode(collections.map((x) => x.toJson()).toList()));
  }
}