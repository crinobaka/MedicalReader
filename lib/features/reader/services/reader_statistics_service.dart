import '../../library/repositories/library_repository.dart';
import '../domain/models/reader_statistics.dart';

class ReaderStatisticsService {
  final LibraryRepository libraryRepository;

  const ReaderStatisticsService({required this.libraryRepository});

  Future<ReaderStatistics> load(String documentId) async {
    final metadata = await libraryRepository.getDocumentMetadata(documentId);
    final raw = metadata?['reader_statistics'];
    if (raw is! Map) return const ReaderStatistics();
    try {
      return ReaderStatistics.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const ReaderStatistics();
    }
  }

  Future<ReaderStatistics> record({
    required String documentId,
    required Duration elapsed,
    required int charactersRead,
    int? totalCharacters,
  }) async {
    final current = await load(documentId);
    final next = current.record(
      elapsed: elapsed,
      charactersRead: charactersRead,
      totalCharacters: totalCharacters,
    );
    await libraryRepository.updateDocumentMetadata(
      documentId: documentId,
      metadata: {'reader_statistics': next.toJson()},
    );
    return next;
  }

  Future<void> save(String documentId, ReaderStatistics statistics) {
    return libraryRepository.updateDocumentMetadata(
      documentId: documentId,
      metadata: {'reader_statistics': statistics.toJson()},
    );
  }
}
