import '../../reader/models/reader_annotation.dart';

/// Knowledge 层使用的 Note 文档模型。
///
/// Markdown 与 Markdown-HTML 是两种互斥的正文格式：
/// - markdown: 正文按照 Markdown 解析。
/// - markdownHtml: 正文直接作为 HTML 交给 HTML renderer。
///
/// 注意：这里不把 HTML 再转回 Markdown，也不会对 markdownHtml 做 Markdown 二次解析。
class NoteDocument {
  final String id;
  final String bookId;
  final int pageIndex;
  final String title;
  final String body;
  final ReaderNoteFormat format;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteDocument({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    required this.title,
    required this.body,
    required this.format,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

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
    return ReaderAnnotation(
      id: id,
      bookId: bookId,
      pageIndex: pageIndex,
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
