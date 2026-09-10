import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../domain/models/reader_sync.dart';
import '../models/reader_annotation.dart';
import 'reader_annotation_service.dart';
import 'reader_progress_service.dart';
import '../domain/models/reader_position.dart';

class ReaderBackupService {
  const ReaderBackupService({
    this.annotationService = const ReaderAnnotationService(),
  });

  final ReaderAnnotationService annotationService;

  Future<File> exportBook({
    required LibraryDocument document,
    required ReaderProgressService progressService,
    required String destinationPath,
  }) async {
    final progress = await progressService.load(document.id);
    final annotations = await annotationService.load(document);
    final payload = <String, dynamic>{
      'schema': 1,
      'book': {
        'id': document.id,
        'title': document.title,
        'format': document.format.name,
      },
      'progress': progress.position?.toJson() ??
          ReaderPosition(progress: 0, spineIndex: progress.lastPage).toJson(),
      'reader': {
        'lastPage': progress.lastPage,
        'zoom': progress.zoom,
        'mode': progress.mode,
        'cropMargins': progress.cropMargins,
      },
      'annotations': [for (final annotation in annotations) annotation.toJson()],
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<int> restoreAnnotations({
    required LibraryDocument document,
    required String backupPath,
  }) async {
    final file = File(backupPath);
    if (!await file.exists()) return 0;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['annotations'] is! List) return 0;
    final restored = (decoded['annotations'] as List)
        .whereType<Map>()
        .map((item) => ReaderAnnotation.fromJson(Map<String, dynamic>.from(item)))
        .map((annotation) => annotation.copyWith(bookId: document.id))
        .toList(growable: false);
    await annotationService.save(document, restored);
    return restored.length;
  }

  ReaderSyncPayload? readSyncPayload(String backupPath) {
    try {
      final decoded = jsonDecode(File(backupPath).readAsStringSync());
      if (decoded is! Map) return null;
      final book = decoded['book'];
      if (book is! Map || book['id'] == null) return null;
      final progress = decoded['progress'];
      final annotations = decoded['annotations'];
      final readerStats = decoded['statistics'];
      return ReaderSyncPayload(
        bookId: book['id'].toString(),
        progress: progress is Map ? (progress['progress'] as num?)?.toDouble() ?? 0 : 0,
        statistics: readerStats is Map ? Map<String, dynamic>.from(readerStats) : const {},
        annotations: annotations is List
            ? annotations.whereType<Map>().map(Map<String, dynamic>.from).toList(growable: false)
            : const [],
        updatedAt: DateTime.tryParse(decoded['exportedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
