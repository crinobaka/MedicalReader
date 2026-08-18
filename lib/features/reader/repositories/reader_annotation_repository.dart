import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import '../services/reader_annotation_service.dart';

/// Annotation 的业务访问层。
///
/// ReaderPage 不直接操作文件。
/// 后续把 JSON 换成 SQLite 时，只修改这一层下面的实现。
class ReaderAnnotationRepository {
  final ReaderAnnotationService service;

  const ReaderAnnotationRepository({
    this.service = const ReaderAnnotationService(),
  });

  Future<List<ReaderAnnotation>> load(
    LibraryDocument document,
  ) {
    return service.load(document);
  }

  Future<void> save(
    LibraryDocument document,
    List<ReaderAnnotation> annotations,
  ) {
    return service.save(document, annotations);
  }

  Future<void> add(
    LibraryDocument document,
    ReaderAnnotation annotation,
  ) async {
    final annotations = await load(document);

    final next = [
      ...annotations.where(
        (item) => item.id != annotation.id,
      ),
      annotation,
    ];

    await save(document, next);
  }

  Future<void> remove(
    LibraryDocument document,
    String annotationId,
  ) async {
    final annotations = await load(document);

    final next = annotations
        .where((item) => item.id != annotationId)
        .toList();

    await save(document, next);
  }
}