import '../../../core/file_manager/models/document_file.dart';

class LibraryDocument {
  final String id;

  final DocumentFile file;

  final String title;

  final int? pages;

  final Map<String, dynamic> metadata;

  final DateTime addedAt;

  const LibraryDocument({
    required this.id,

    required this.file,

    required this.title,

    this.pages,

    this.metadata = const {},

    required this.addedAt,
  });

  factory LibraryDocument.fromFile(DocumentFile file) {
    return LibraryDocument(
      id: file.path,

      file: file,

      title: file.name.replaceAll('.pdf', ''),

      pages: null,

      metadata: {},

      addedAt: DateTime.now(),
    );
  }
}
