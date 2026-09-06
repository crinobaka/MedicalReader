import 'dart:io';

import '../../../core/file_manager/models/document_file.dart';
import '../../../library/models/library_document.dart';
import '../../epub/models/epub_book.dart';
import '../../epub/services/epub_archive_service.dart';
import '../models/reader_document.dart';
import '../models/reader_locator.dart';
import '../models/reader_outline.dart';
import '../models/reader_position.dart';
import 'reader_document_adapter.dart';

class EpubReaderDocument implements ReaderDocument {
  final LibraryDocument libraryDocument;
  final EpubArchive archive;
  const EpubReaderDocument({required this.libraryDocument, required this.archive});
  @override String get id => libraryDocument.id;
  @override String get title => archive.book.title;
  @override ReaderDocumentFormat get format => ReaderDocumentFormat.epub;
  @override ReaderPositionData get initialPositionData => const ReaderPositionData(progress: 0);
}

class EpubReaderDocumentAdapter implements ReaderDocumentAdapter {
  final EpubArchiveService archiveService;
  final Future<Directory> Function()? cacheProvider;
  const EpubReaderDocumentAdapter({this.archiveService = const EpubArchiveService(), this.cacheProvider});

  @override ReaderDocumentFormat get format => ReaderDocumentFormat.epub;

  @override
  Future<ReaderDocument> open({required String id, required String path}) async {
    final archive = await archiveService.open(path, await _cacheDirectory());
    return EpubReaderDocument(libraryDocument: LibraryDocument.fromFile(_file(path, id)), archive: archive);
  }

  @override
  Future<void> close(ReaderDocument document) async {
    if (document is EpubReaderDocument) await archiveService.close(document.archive);
  }

  @override
  Future<List<ReaderOutlineItem>> loadOutline(ReaderDocument document) async {
    if (document is! EpubReaderDocument) throw ArgumentError.value(document, 'document');
    return [for (final item in document.archive.book.navigation) _outline(item)];
  }

  @override
  Future<ReaderPosition> resolvePosition(ReaderDocument document, ReaderLocator locator) async {
    if (document is! EpubReaderDocument || locator is! EpubReaderLocator) throw ArgumentError('Expected EPUB document and EPUB locator.');
    return ReaderPosition(locator: locator, progress: locator.progress ?? 0);
  }

  ReaderOutlineItem _outline(EpubNavItem item) {
    final uri = Uri.parse(item.href);
    return ReaderOutlineItem(
      id: item.href,
      title: item.title,
      target: EpubOutlineTarget(href: uri.path, fragment: uri.fragment.isEmpty ? null : uri.fragment),
      children: [for (final child in item.children) _outline(child)],
    );
  }

  Future<Directory> _cacheDirectory() async => cacheProvider == null ? Directory.systemTemp : cacheProvider!();

  DocumentFile _file(String path, String id) => DocumentFile(
    id: id,
    name: path.split(RegExp(r'[\\/]')).last,
    path: path,
    size: File(path).lengthSync(),
    createdAt: DateTime.now(),
  );
}
