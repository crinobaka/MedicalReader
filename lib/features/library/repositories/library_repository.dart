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

  LibraryRepository({
    required this.loadFiles,
    required this.addFileAction,
    required this.initializeFilesAction,
    required this.metadataStorageFuture,
  });

  Future<void> addFile() async {
    await initializeFilesAction();
    await addFileAction();
  }

  Future<void> initialize() {
    return _initializeFuture ??= _loadMetadata();
  }

  List<LibraryDocument> getDocuments() {
    final files = loadFiles();
    return files.map((file) {
      final storedJson = _documentJsonById[file.id];
      if (storedJson == null) return LibraryDocument.fromFile(file);
      try {
        return LibraryDocument.fromJson(storedJson, file);
      } catch (_) {
        return LibraryDocument.fromFile(file);
      }
    }).toList();
  }

  Future<void> _loadMetadata() async {
    final storage = await metadataStorageFuture;
    final documents = await storage.load();
    _documentJsonById.clear();
    for (final document in documents) {
      final id = document['id'];
      if (id is String && id.isNotEmpty) {
        _documentJsonById[id] = Map<String, dynamic>.from(document);
      }
    }
  }

  Future<Map<String, dynamic>?> getDocumentMetadata(String documentId) async {
    await initialize();
    final document = _documentJsonById[documentId];
    if (document == null) return null;
    final metadata = document['metadata'];
    if (metadata is! Map) return null;
    return Map<String, dynamic>.from(metadata);
  }

  Future<void> updateDocumentMetadata({
    required String documentId,
    required Map<String, dynamic> metadata,
  }) async {
    await initialize();
    final document = _documentJsonById[documentId];
    if (document == null) return;

    final mergedMetadata = <String, dynamic>{};
    final existingMetadata = document['metadata'];
    if (existingMetadata is Map) {
      mergedMetadata.addAll(Map<String, dynamic>.from(existingMetadata));
    }
    mergedMetadata.addAll(metadata);
    document['metadata'] = mergedMetadata;
    await _persist();
  }

  Future<void> saveDocuments(List<LibraryDocument> documents) async {
    await initialize();

    // 不因为一次文件系统扫描失败/权限暂时失效，就把历史 metadata 清空。
    // 真正删除文档必须经过 removeDocument()，避免 Android 外部存储恢复权限后
    // 出现“PDF 和 metadata 都消失”的数据丢失问题。
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
    final fileById = <String, DocumentFile>{
      for (final file in files) file.id: file,
    };

    final documents = <LibraryDocument>[];

    // 只把当前确实存在的 PDF 写回 metadata；暂时不可访问的历史记录保留在
    // 内存映射中，不参与本次序列化，下一次恢复访问后即可重新显示。
    for (final json in _documentJsonById.values) {
      final id = json['id'];
      if (id is! String) continue;

      final file = fileById[id];
      if (file == null) continue;

      try {
        documents.add(LibraryDocument.fromJson(json, file));
      } catch (_) {
        continue;
      }
    }

    final operation = _writeQueue.then((_) => storage.save(documents));
    _writeQueue = operation.then<void>((_) {}, onError: (_, __) {});
    await operation;
  }
}
