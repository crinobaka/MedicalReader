import 'dart:async';

import '../../../core/file_manager/models/document_file.dart';
import '../models/library_document.dart';
import '../storage/library_metadata_storage.dart';

class LibraryRepository {
  final List<DocumentFile> Function() loadFiles;
  final Future<DocumentFile?> Function() addFileAction;
  final Future<void> Function() initializeFilesAction;
  final Future<LibraryMetadataStorage> metadataStorageFuture;

  final Map<String, Map<String, dynamic>> _documentJsonById = {};
  Future<void>? _initializeFuture;
  Future<void> _writeQueue = Future<void>.value();

  LibraryRepository({required this.loadFiles, required this.addFileAction, required this.initializeFilesAction, required this.metadataStorageFuture});

  Future<void> addFile() async { await initializeFilesAction(); await addFileAction(); }
  Future<void> initialize() => _initializeFuture ??= _loadMetadata();

  List<LibraryDocument> getDocuments() {
    final files = loadFiles();
    return files.map((file) {
      final storedJson = _documentJsonById[file.id];
      if (storedJson == null) return LibraryDocument.fromFile(file);
      try { return LibraryDocument.fromJson(storedJson, file); } catch (_) { return LibraryDocument.fromFile(file); }
    }).toList();
  }

  Future<void> _loadMetadata() async {
    final storage = await metadataStorageFuture;
    final documents = await storage.load();
    _documentJsonById.clear();
    for (final document in documents) {
      final id = document['id'];
      if (id is String && id.isNotEmpty) _documentJsonById[id] = Map<String, dynamic>.from(document);
    }
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
    // 扫描不到文件时不能清空历史记录；外部存储权限可能只是暂时失效。
    for (final document in documents) {
      _documentJsonById[document.id] = document.toJson();
    }
    await _persist();
  }

  Future<void> removeDocument(String documentId) async {
    await initialize();
    _documentJsonById.remove(documentId);
    await _persist();
  }

  Future<void> _persist() async {
    final storage = await metadataStorageFuture;
    final files = loadFiles();
    final fileIds = files.map((file) => file.id).toSet();
    final output = <Map<String, dynamic>>[];

    // 保留所有已知 metadata，而不是只序列化本次扫描到的 PDF。
    // 这样 Android 外部存储暂时不可访问时，重启不会把历史记录永久抹掉。
    for (final json in _documentJsonById.values) {
      final id = json['id'];
      if (id is String && id.isNotEmpty) {
        output.add(Map<String, dynamic>.from(json));
      }
    }

    // 当前文件系统中出现的新 PDF 也进入 metadata，保持后续 metadata API 一致。
    for (final file in files) {
      if (fileIds.contains(file.id) && !_documentJsonById.containsKey(file.id)) {
        output.add(LibraryDocument.fromFile(file).toJson());
      }
    }

    final operation = _writeQueue.then((_) => storage.saveJson(output));
    _writeQueue = operation.then<void>((_) {}, onError: (_, __) {});
    await operation;
  }
}
