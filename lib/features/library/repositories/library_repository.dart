import 'dart:async';

import '../../../core/file_manager/models/document_file.dart';
import '../models/library_collection.dart';
import '../models/library_document.dart';
import '../storage/library_collections_storage.dart';
import '../storage/library_metadata_storage.dart';

class LibraryRepository {
  final List<DocumentFile> Function() loadFiles;
  final Future<DocumentFile?> Function() addFileAction;
  final Future<void> Function() initializeFilesAction;
  final Future<LibraryMetadataStorage> Function() metadataStorageFactory;
  final Future<LibraryCollectionsStorage> Function() collectionsStorageFactory;

  final Map<String, Map<String, dynamic>> _documentJsonById = {};
  List<LibraryCollection> _collections = const [];
  Future<void>? _initializeFuture;
  Future<void>? _collectionsFuture;
  Future<void> _writeQueue = Future<void>.value();

  LibraryRepository({
    required this.loadFiles,
    required this.addFileAction,
    required this.initializeFilesAction,
    required this.metadataStorageFactory,
    required this.collectionsStorageFactory,
  });

  Future<void> addFile() async { await initializeFilesAction(); await addFileAction(); }
  Future<void> initialize() => _initializeFuture ??= _loadMetadata();
  Future<void> initializeCollections() => _collectionsFuture ??= _loadCollections();

  List<LibraryDocument> getDocuments() {
    final files = loadFiles();
    return files.map((file) {
      final storedJson = _documentJsonById[file.id];
      if (storedJson == null) return LibraryDocument.fromFile(file);
      try { return LibraryDocument.fromJson(storedJson, file); } catch (_) { return LibraryDocument.fromFile(file); }
    }).toList();
  }

  Future<void> _loadMetadata() async {
    final storage = await metadataStorageFactory();
    final documents = await storage.load();
    _documentJsonById.clear();
    for (final document in documents) {
      final id = document['id'];
      if (id is String && id.isNotEmpty) _documentJsonById[id] = Map<String, dynamic>.from(document);
    }
  }

  Future<void> _loadCollections() async {
    _collections = await (await collectionsStorageFactory()).load();
  }

  Future<List<LibraryCollection>> getCollections() async {
    await initializeCollections();
    return List.unmodifiable(_collections);
  }

  Future<LibraryCollection?> createCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    await initializeCollections();
    if (_collections.any((x) => x.name.toLowerCase() == trimmed.toLowerCase())) return null;
    final now = DateTime.now();
    final collection = LibraryCollection(id: 'collection_${now.microsecondsSinceEpoch}', name: trimmed, createdAt: now);
    _collections = [..._collections, collection];
    await (await collectionsStorageFactory()).save(_collections);
    return collection;
  }

  Future<bool> renameCollection(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await initializeCollections();
    if (_collections.any((x) => x.id != id && x.name.toLowerCase() == trimmed.toLowerCase())) return false;
    if (!_collections.any((x) => x.id == id)) return false;
    _collections = [for (final x in _collections) x.id == id ? LibraryCollection(id: x.id, name: trimmed, createdAt: x.createdAt) : x];
    await (await collectionsStorageFactory()).save(_collections);
    return true;
  }

  Future<void> deleteCollection(String id) async {
    await initializeCollections();
    _collections = _collections.where((x) => x.id != id).toList(growable: false);
    await (await collectionsStorageFactory()).save(_collections);
    for (final document in getDocuments()) {
      final ids = _collectionIds(document).where((x) => x != id).toList(growable: false);
      await updateDocumentMetadata(documentId: document.id, metadata: {'collection_ids': ids});
    }
  }

  List<String> _collectionIds(LibraryDocument document) {
    final raw = document.metadata['collection_ids'];
    if (raw is! List) return const [];
    return raw.map((x) => x.toString()).where((x) => x.isNotEmpty).toSet().toList(growable: false);
  }

  Future<List<String>> getDocumentCollectionIds(String documentId) async {
    final metadata = await getDocumentMetadata(documentId);
    final raw = metadata?['collection_ids'];
    if (raw is! List) return const [];
    return raw.map((x) => x.toString()).where((x) => x.isNotEmpty).toSet().toList(growable: false);
  }

  Future<void> setDocumentCollections({required String documentId, required List<String> collectionIds}) async {
    await updateDocumentMetadata(documentId: documentId, metadata: {'collection_ids': collectionIds.toSet().toList(growable: false)});
  }

  Future<Map<String, dynamic>?> getDocumentMetadata(String documentId) async {
    await initialize();
    final document = _documentJsonById[documentId];
    if (document == null) return null;
    final metadata = document['metadata'];
    return metadata is Map ? Map<String, dynamic>.from(metadata) : null;
  }

  Future<void> updateDocumentMetadata({required String documentId, required Map<String, dynamic> metadata}) async {
    await initialize();
    final document = _documentJsonById[documentId];
    if (document == null) return;
    final merged = <String, dynamic>{};
    final existing = document['metadata'];
    if (existing is Map) merged.addAll(Map<String, dynamic>.from(existing));
    merged.addAll(metadata);
    document['metadata'] = merged;
    await _persist();
  }

  Future<void> saveDocuments(List<LibraryDocument> documents) async {
    await initialize();
    for (final document in documents) { _documentJsonById[document.id] = document.toJson(); }
    await _persist();
  }

  Future<void> removeDocument(String documentId) async {
    await initialize();
    _documentJsonById.remove(documentId);
    await _persist();
  }

  Future<void> _persist() async {
    final storage = await metadataStorageFactory();
    final files = loadFiles();
    final fileIds = files.map((file) => file.id).toSet();
    final output = <Map<String, dynamic>>[];
    for (final json in _documentJsonById.values) {
      final id = json['id'];
      if (id is String && id.isNotEmpty) output.add(Map<String, dynamic>.from(json));
    }
    for (final file in files) {
      if (fileIds.contains(file.id) && !_documentJsonById.containsKey(file.id)) output.add(LibraryDocument.fromFile(file).toJson());
    }
    final operation = _writeQueue.then((_) => storage.saveJson(output));
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    await operation;
  }

  Future<void> reloadMetadata() async {
    final storage = await metadataStorageFactory();
    final documents = await storage.load();
    _documentJsonById.clear();
    for (final document in documents) {
      final id = document['id'];
      if (id is String && id.isNotEmpty) _documentJsonById[id] = Map<String, dynamic>.from(document);
    }
  }
}