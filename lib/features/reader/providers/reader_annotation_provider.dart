import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import '../repositories/reader_annotation_repository.dart';

final readerAnnotationRepositoryProvider =
    Provider<ReaderAnnotationRepository>((ref) {
  return const ReaderAnnotationRepository();
});

final readerAnnotationsProvider = StateNotifierProvider.family<
    ReaderAnnotationsNotifier,
    List<ReaderAnnotation>,
    LibraryDocument>(
  (ref, document) {
    return ReaderAnnotationsNotifier(
      document: document,
      repository: ref.read(
        readerAnnotationRepositoryProvider,
      ),
    )..load();
  },
);

class ReaderAnnotationsNotifier
    extends StateNotifier<List<ReaderAnnotation>> {
  final LibraryDocument document;
  final ReaderAnnotationRepository repository;

  ReaderAnnotationsNotifier({
    required this.document,
    required this.repository,
  }) : super(const []);

  Future<void> load() async {
    state = await repository.load(document);
  }

  Future<void> add(ReaderAnnotation annotation) async {
    await repository.add(document, annotation);

    state = [
      ...state.where(
        (item) => item.id != annotation.id,
      ),
      annotation,
    ];
  }

  Future<void> remove(String annotationId) async {
    await repository.remove(
      document,
      annotationId,
    );

    state = state
        .where((item) => item.id != annotationId)
        .toList();
  }
}