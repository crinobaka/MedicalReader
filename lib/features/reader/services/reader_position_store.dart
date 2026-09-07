import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../domain/models/reader_locator.dart';
import '../domain/models/reader_position.dart';

final readerPositionStoreProvider = Provider<ReaderPositionStore>((ref) {
  return ReaderPositionStore(ref.read(libraryRepositoryProvider));
});

class ReaderPositionStore {
  final dynamic _repository;

  const ReaderPositionStore(this._repository);

  ReaderPosition? read(LibraryDocument document) {
    final raw = document.metadata['reader_position'];
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      final locatorJson = json['locator'];
      final locator = ReaderLocator.fromJson(
        locatorJson is Map ? Map<String, dynamic>.from(locatorJson) : json,
      );
      final progress = (json['progress'] as num?)?.toDouble() ?? 0;
      return ReaderPosition(
        locator: locator,
        progress: progress.clamp(0, 1).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LibraryDocument document, ReaderPosition position) {
    return _repository.updateDocumentMetadata(
      documentId: document.id,
      metadata: {
        'reader_position': position.toJson(),
        'last_read_at': DateTime.now().toIso8601String(),
      },
    );
  }
}
