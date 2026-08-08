import '../../../core/file_manager/models/document_file.dart';

class LibraryDocument {
  final DocumentFile file;

  final String title;

  final DateTime addedAt;

  const LibraryDocument({
    required this.file,

    required this.title,

    required this.addedAt,
  });

  factory LibraryDocument.fromFile(DocumentFile file) {
    return LibraryDocument(
      file: file,

      title: file.name.replaceAll('.pdf', ''),

      addedAt: DateTime.now(),
    );
  }
}
