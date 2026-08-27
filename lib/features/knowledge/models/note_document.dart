import '../../reader/models/reader_annotation.dart';

/// 独立知识笔记模型。
///
/// bookId/pageIndex 可为空：为空表示笔记已经与书籍解绑，
/// 解绑后的笔记仍然可以保存、编辑和导出，不依赖 LibraryDocument 生命周期。
class NoteDocument {
  final String id;
  final String? bookId;
  final int? pageIndex;
  final String title;
  final String body;
  final ReaderNoteFormat format;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteDocument({
    required this.id,
    this.bookId,
    this.pageIndex,
    required this.title,
    required this.body,
    required this.format,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDetached => bookId == null || pageIndex == null;

  NoteDocument detach() => NoteDocument(
        id: id,
        title: title,
        body: body,
        format: format,
        attachments: attachments,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory NoteDocument.fromAnnotation(ReaderAnnotation annotation) {
    return NoteDocument(
      id: annotation.id,
      bookId: annotation.bookId,
      pageIndex: annotation.pageIndex,
      title: annotation.title,
      body: annotation.content,
      format: annotation.noteFormat,
      attachments: List.unmodifiable(annotation.attachments),
      createdAt: annotation.createdAt,
      updatedAt: annotation.updatedAt,
    );
  }

  ReaderAnnotation toAnnotation() {
    if (isDetached) {
      throw StateError('Detached notes cannot be converted to ReaderAnnotation.');
    }
    return ReaderAnnotation(
      id: id,
      bookId: bookId!,
      pageIndex: pageIndex!,
      type: ReaderAnnotationType.note,
      title: title,
      content: body,
      noteFormat: format,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
