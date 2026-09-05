import '../../library/repositories/library_repository.dart';

class ReaderProgress {
  final int lastPage;
  final double zoom;
  final String mode;
  final bool cropMargins;
  final DateTime? lastReadAt;

  const ReaderProgress({
    required this.lastPage,
    required this.zoom,
    required this.mode,
    required this.cropMargins,
    this.lastReadAt,
  });

  static const ReaderProgress initial = ReaderProgress(
    lastPage: 0,
    zoom: 1.0,
    mode: 'medical',
    cropMargins: false,
  );
}

class ReaderProgressService {
  final LibraryRepository libraryRepository;

  const ReaderProgressService({required this.libraryRepository});

  Future<ReaderProgress> load(String documentId) async {
    final metadata = await libraryRepository.getDocumentMetadata(documentId);
    if (metadata == null) return ReaderProgress.initial;

    final lastPage = _readInt(metadata['last_page'], 0);
    final zoom = _readDouble(metadata['zoom'], 1.0);
    final mode = metadata['mode'] is String ? metadata['mode'] as String : 'medical';
    final cropMargins = metadata['crop_margins'] is bool ? metadata['crop_margins'] as bool : false;
    final lastReadAt = _readDateTime(metadata['last_read_at']);

    return ReaderProgress(
      lastPage: lastPage < 0 ? 0 : lastPage,
      zoom: zoom > 0 ? zoom : 1.0,
      mode: mode,
      cropMargins: cropMargins,
      lastReadAt: lastReadAt,
    );
  }

  /// Updates the complete reader state without deleting unrelated metadata.
  Future<void> save({
    required String documentId,
    required int lastPage,
    double zoom = 1.0,
    String mode = 'medical',
    bool cropMargins = false,
  }) async {
    await libraryRepository.updateDocumentMetadata(
      documentId: documentId,
      metadata: {
        'last_page': lastPage,
        'zoom': zoom,
        'mode': mode,
        'crop_margins': cropMargins,
        'last_read_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Saves only the current page. This is intentionally separate from [save]
  /// so changing pages cannot silently reset zoom, mode, or other reader state.
  Future<void> savePage({
    required String documentId,
    required int lastPage,
  }) async {
    await libraryRepository.updateDocumentMetadata(
      documentId: documentId,
      metadata: {
        'last_page': lastPage,
        'last_read_at': DateTime.now().toIso8601String(),
      },
    );
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  double _readDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return fallback;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
