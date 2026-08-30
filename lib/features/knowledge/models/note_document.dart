import '../../reader/models/reader_annotation.dart';

/// Independent knowledge note. bookId/pageIndex may be null after detaching.
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'pageIndex': pageIndex,
        'title': title,
        'body': body,
        'format': format.name,
        'attachments': attachments,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NoteDocument.fromJson(Map<String, dynamic> json) => NoteDocument(
        id: json['id']?.toString() ?? '',
        bookId: json['bookId']?.toString(),
        pageIndex: (json['pageIndex'] as num?)?.toInt(),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        format: ReaderNoteFormat.values.firstWhere(
          (value) => value.name == json['format']?.toString(),
          orElse: () => ReaderNoteFormat.markdown,
        ),
        attachments: json['attachments'] is List
            ? (json['attachments'] as List).map((value) => value.toString()).toList()
            : const [],
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
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
