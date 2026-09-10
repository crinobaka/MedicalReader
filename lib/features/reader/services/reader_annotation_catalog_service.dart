import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import 'reader_annotation_service.dart';

class ReaderAnnotationCatalog {
  final List<ReaderAnnotation> annotations;

  const ReaderAnnotationCatalog(this.annotations);

  List<ReaderAnnotation> get highlights => _where(ReaderAnnotationType.highlight);
  List<ReaderAnnotation> get notes => _where(ReaderAnnotationType.note);
  List<ReaderAnnotation> get bookmarks => _where(ReaderAnnotationType.bookmark);
  List<ReaderAnnotation> get tags => _where(ReaderAnnotationType.tag);
  List<ReaderAnnotation> get ink => _where(ReaderAnnotationType.ink);

  List<ReaderAnnotation> _where(ReaderAnnotationType type) => annotations
      .where((item) => item.type == type)
      .toList(growable: false);

  List<ReaderAnnotation> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return annotations;
    return annotations.where((item) {
      return item.content.toLowerCase().contains(needle) ||
          item.title.toLowerCase().contains(needle);
    }).toList(growable: false);
  }

  List<ReaderAnnotation> forPage(int pageIndex) => annotations
      .where((item) => item.pageIndex == pageIndex)
      .toList(growable: false);
}

class ReaderAnnotationCatalogService {
  final ReaderAnnotationService annotationService;

  const ReaderAnnotationCatalogService({
    this.annotationService = const ReaderAnnotationService(),
  });

  Future<ReaderAnnotationCatalog> load(LibraryDocument document) async {
    final items = await annotationService.load(document);
    return ReaderAnnotationCatalog(List.unmodifiable(items));
  }

  Future<ReaderAnnotationCatalog> add({
    required LibraryDocument document,
    required ReaderAnnotation annotation,
  }) async {
    final current = await annotationService.load(document);
    final next = [
      ...current.where((item) => item.id != annotation.id),
      annotation,
    ];
    await annotationService.save(document, next);
    return ReaderAnnotationCatalog(List.unmodifiable(next));
  }

  Future<ReaderAnnotationCatalog> remove({
    required LibraryDocument document,
    required String annotationId,
  }) async {
    final current = await annotationService.load(document);
    final next = current.where((item) => item.id != annotationId).toList(growable: false);
    await annotationService.save(document, next);
    return ReaderAnnotationCatalog(List.unmodifiable(next));
  }
}
