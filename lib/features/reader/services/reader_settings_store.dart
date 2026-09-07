import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../domain/models/reader_settings.dart';

final readerSettingsStoreProvider = Provider<ReaderSettingsStore>((ref) {
  return ReaderSettingsStore(ref.read(libraryRepositoryProvider));
});

class ReaderSettingsStore {
  final dynamic _repository;

  const ReaderSettingsStore(this._repository);

  Future<ReaderSettings> load(LibraryDocument document) async {
    final raw = document.metadata['reader_settings'];
    if (raw is Map) {
      return ReaderSettings.fromJson(Map<String, dynamic>.from(raw));
    }
    final stored = await _repository.getDocumentMetadata(document.id);
    final storedRaw = stored?['reader_settings'];
    if (storedRaw is Map) {
      return ReaderSettings.fromJson(Map<String, dynamic>.from(storedRaw));
    }
    return const ReaderSettings();
  }

  Future<void> save(LibraryDocument document, ReaderSettings settings) {
    return _repository.updateDocumentMetadata(
      documentId: document.id,
      metadata: {'reader_settings': settings.toJson()},
    );
  }
}
