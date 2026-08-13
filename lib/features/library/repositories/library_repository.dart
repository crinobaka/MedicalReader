import 'dart:async';

import '../../../core/file_manager/models/document_file.dart';
import '../models/library_document.dart';
import '../storage/library_metadata_storage.dart';

class LibraryRepository {
  final List<DocumentFile> Function() loadFiles;

  final Future<void> Function() addFileAction;

  final Future<LibraryMetadataStorage>
      metadataStorageFuture;

  final Map<String, Map<String, dynamic>>
      _documentJsonById = {};

  Future<void>? _initializeFuture;

  Future<void> _writeQueue = Future<void>.value();

  LibraryRepository({
    required this.loadFiles,
    required this.addFileAction,
    required this.metadataStorageFuture,
  });

  Future<void> addFile() async {
    await addFileAction();
  }

  List<LibraryDocument> getDocuments() {
    final files = loadFiles();

    return files.map(
      (file) {
        final storedJson =
            _documentJsonById[file.path];

        if (storedJson == null) {
          return LibraryDocument.fromFile(file);
        }

        try {
          return LibraryDocument.fromJson(
            storedJson,
            file,
          );
        } catch (_) {
          return LibraryDocument.fromFile(file);
        }
      },
    ).toList();
  }

  Future<void> initialize() {
    return _initializeFuture ??= _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final storage = await metadataStorageFuture;

    final documents = await storage.load();

    _documentJsonById.clear();

    for (final document in documents) {
      final id = document['id'];

      if (id is String && id.isNotEmpty) {
        _documentJsonById[id] =
            Map<String, dynamic>.from(document);
      }
    }
  }

  Future<Map<String, dynamic>?> getDocumentMetadata(
    String documentId,
  ) async {
    await initialize();

    final document =
        _documentJsonById[documentId];

    if (document == null) {
      return null;
    }

    final metadata =
        document['metadata'];

    if (metadata is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(
      metadata,
    );
  }

  Future<void> updateDocumentMetadata({
    required String documentId,
    required Map<String, dynamic> metadata,
  }) async {
    await initialize();

    final document =
        _documentJsonById[documentId];

    if (document == null) {
      return;
    }

    final existingMetadata =
        document['metadata'];

    final mergedMetadata =
        <String, dynamic>{};

    if (existingMetadata is Map) {
      mergedMetadata.addAll(
        Map<String, dynamic>.from(
          existingMetadata,
        ),
      );
    }

    mergedMetadata.addAll(metadata);

    document['metadata'] =
        mergedMetadata;

    await _persist();
  }

  Future<void> saveDocuments(
    List<LibraryDocument> documents,
  ) async {
    await initialize();

    final currentIds =
        documents.map(
          (document) => document.id,
        ).toSet();

    _documentJsonById.removeWhere(
      (id, _) => !currentIds.contains(id),
    );

    for (final document in documents) {
      _documentJsonById[document.id] =
          document.toJson();
    }

    await _persist();
  }

  Future<void> _persist() async {
    final storage =
        await metadataStorageFuture;

    final documents = <LibraryDocument>[];

    for (final json
        in _documentJsonById.values) {
      final id = json['id'];

      if (id is! String) {
        continue;
      }

      final files = loadFiles();

      DocumentFile? file;

      for (final candidate in files) {
        if (candidate.path == id) {
          file = candidate;
          break;
        }
      }

      if (file == null) {
        continue;
      }

      try {
        documents.add(
          LibraryDocument.fromJson(
            json,
            file,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    final operation = _writeQueue.then(
      (_) => storage.save(documents),
    );

    _writeQueue = operation.then<void>(
      (_) {},
      onError: (_, __) {},
    );

    await operation;
  }
}