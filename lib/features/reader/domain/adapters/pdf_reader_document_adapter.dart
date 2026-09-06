import '../../../library/models/library_document.dart';
import '../models/reader_document.dart';
import '../models/reader_locator.dart';
import '../models/reader_outline.dart';
import '../models/reader_position.dart';
import 'reader_document_adapter.dart';

class PdfReaderDocument implements ReaderDocument {
  final LibraryDocument libraryDocument;

  const PdfReaderDocument(this.libraryDocument);

  @override
  String get id => libraryDocument.id;

  @override
  String get title => libraryDocument.title;

  @override
  ReaderDocumentFormat get format => ReaderDocumentFormat.pdf;

  @override
  ReaderPositionData get initialPositionData => const ReaderPositionData(pageIndex: 0);
}

class PdfReaderDocumentAdapter implements ReaderDocumentAdapter {
  const PdfReaderDocumentAdapter();

  @override
  ReaderDocumentFormat get format => ReaderDocumentFormat.pdf;

  @override
  Future<ReaderDocument> open({
    required String id,
    required String path,
  }) {
    throw UnsupportedError(
      'PdfReaderDocumentAdapter is the domain boundary only. '
      'Opening is still owned by ReaderPageController.',
    );
  }

  @override
  Future<void> close(ReaderDocument document) async {}

  @override
  Future<List<ReaderOutlineItem>> loadOutline(ReaderDocument document) async => const [];

  @override
  Future<ReaderPosition> resolvePosition(
    ReaderDocument document,
    ReaderLocator locator,
  ) async {
    if (locator is! PdfReaderLocator) {
      throw ArgumentError.value(locator, 'locator', 'Expected a PDF locator.');
    }
    return ReaderPosition(
      locator: locator,
      progress: 0,
    );
  }
}
