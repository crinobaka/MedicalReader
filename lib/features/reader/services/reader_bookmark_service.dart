import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import 'reader_annotation_service.dart';

class ReaderBookmarkService {
  final ReaderAnnotationService annotationService;
  const ReaderBookmarkService({this.annotationService = const ReaderAnnotationService()});

  Future<List<ReaderAnnotation>> load(LibraryDocument document) async {
    final items = await annotationService.load(document);
    return items.where((item) => item.type == ReaderAnnotationType.bookmark).toList(growable: false);
  }

  Future<bool> toggle({required LibraryDocument document, required int pageIndex}) async {
    final items = await annotationService.load(document);
    final matches = items.where((item) => item.type == ReaderAnnotationType.bookmark && item.pageIndex == pageIndex).toList();
    final next = matches.isEmpty
        ? [...items, _bookmark(document, pageIndex)]
        : items.where((item) => !matches.any((match) => match.id == item.id)).toList(growable: false);
    await annotationService.save(document, next);
    return matches.isEmpty;
  }

  ReaderAnnotation _bookmark(LibraryDocument document, int pageIndex) {
    final now = DateTime.now();
    return ReaderAnnotation(
      id: 'bookmark_${document.id}_$pageIndex',
      bookId: document.id,
      pageIndex: pageIndex,
      type: ReaderAnnotationType.bookmark,
      createdAt: now,
      updatedAt: now,
    );
  }
}
