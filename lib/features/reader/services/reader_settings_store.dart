import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../../library/repositories/library_repository.dart';
import '../domain/models/reader_settings.dart';

final readerSettingsStoreProvider = Provider<ReaderSettingsStore>((ref) {
  return ReaderSettingsStore(ref.read(libraryRepositoryProvider));
});

/// Single persistence boundary for reader settings.
///
/// Global settings live in ApplicationSupport and act as the default profile.
/// A document may override them through its library metadata. This gives PDF
/// and EPUB the same schema while preserving per-book customization.
class ReaderSettingsStore {
  static const _globalFileName = 'reader_settings.json';

  final LibraryRepository _repository;

  const ReaderSettingsStore(this._repository);

  Future<ReaderSettings> loadGlobal() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_globalFileName');
      if (!await file.exists()) return const ReaderSettings();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const ReaderSettings();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ReaderSettings.fromJson(decoded);
      if (decoded is Map) return ReaderSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // Corrupt or inaccessible settings fall back to defaults.
    }
    return const ReaderSettings();
  }

  Future<void> saveGlobal(ReaderSettings settings) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/$_globalFileName');
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<ReaderSettings> load(LibraryDocument document) async {
    final raw = document.metadata['reader_settings'];
    if (raw is Map) return ReaderSettings.fromJson(Map<String, dynamic>.from(raw));

    final stored = await _repository.getDocumentMetadata(document.id);
    final storedRaw = stored?['reader_settings'];
    if (storedRaw is Map) return ReaderSettings.fromJson(Map<String, dynamic>.from(storedRaw));

    return loadGlobal();
  }

  Future<void> save(LibraryDocument document, ReaderSettings settings) {
    return _repository.updateDocumentMetadata(
      documentId: document.id,
      metadata: {'reader_settings': settings.toJson()},
    );
  }

  Future<void> clear(LibraryDocument document) {
    return _repository.updateDocumentMetadata(
      documentId: document.id,
      metadata: {'reader_settings': null},
    );
  }
}
