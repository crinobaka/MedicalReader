import '../models/reader_document.dart';
import '../models/reader_locator.dart';
import '../models/reader_outline.dart';

abstract interface class ReaderDocumentAdapter {
  ReaderDocumentFormat get format;

  Future<ReaderDocument> open({
    required String id,
    required String path,
  });

  Future<void> close(ReaderDocument document);

  Future<List<ReaderOutlineItem>> loadOutline(ReaderDocument document);

  Future<ReaderPosition> resolvePosition(
    ReaderDocument document,
    ReaderLocator locator,
  );
}
