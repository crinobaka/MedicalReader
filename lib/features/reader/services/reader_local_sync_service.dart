import 'dart:convert';

import '../../library/repositories/library_repository.dart';
import '../domain/models/reader_sync.dart';

class ReaderLocalSyncService implements ReaderSyncService {
  final LibraryRepository libraryRepository;

  const ReaderLocalSyncService({required this.libraryRepository});

  @override
  Future<void> push(ReaderSyncPayload payload) async {
    await libraryRepository.updateDocumentMetadata(
      documentId: payload.bookId,
      metadata: {
        'reader_sync_payload': payload.toJson(),
        'reader_sync_updated_at': payload.updatedAt.toIso8601String(),
      },
    );
  }

  @override
  Future<ReaderSyncPayload?> pull(String bookId) async {
    final metadata = await libraryRepository.getDocumentMetadata(bookId);
    final raw = metadata?['reader_sync_payload'];
    if (raw is! Map) return null;
    try {
      return ReaderSyncPayload.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}

class ReaderBackupCodec {
  const ReaderBackupCodec();

  String encode(ReaderSyncPayload payload) =>
      const JsonEncoder.withIndent('  ').convert(payload.toJson());

  ReaderSyncPayload decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map) throw const FormatException('Invalid reader backup.');
    return ReaderSyncPayload.fromJson(Map<String, dynamic>.from(value));
  }
}
