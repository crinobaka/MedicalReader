import 'dart:io';

import '../../../../core/file_manager/models/document_file.dart';
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
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('PDF file does not exist.', path);
    }
    final stat = await file.stat();
    final name = path.split(RegExp(r'[\\/]')).last;
    final documentFile = DocumentFile(
      id: id,
      name: name,
      path: path,
      size: stat.size,
      createdAt: stat.changed,
    );
    return PdfReaderDocument(LibraryDocument.fromFile(documentFile));
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
    if (document.format != ReaderDocumentFormat.pdf) {
      throw ArgumentError.value(document, 'document', 'Expected a PDF document.');
    }
    if (locator is! PdfReaderLocator) {
      throw ArgumentError.value(locator, 'locator', 'Expected a PDF locator.');
    }
    return ReaderPosition(
      locator: locator,
      progress: locator.pageIndex < 0 ? 0 : locator.pageIndex.toDouble(),
    );
  }
}
