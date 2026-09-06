import '../../../../core/file_manager/models/document_file.dart';

enum LibraryDocumentFormat { pdf, epub, other }

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

  LibraryDocumentFormat get format {
    final name = file.name.toLowerCase();
    if (name.endsWith('.pdf')) return LibraryDocumentFormat.pdf;
    if (name.endsWith('.epub')) return LibraryDocumentFormat.epub;
    return LibraryDocumentFormat.other;
  }

  bool get isPdf => format == LibraryDocumentFormat.pdf;
  bool get isEpub => format == LibraryDocumentFormat.epub;

  factory LibraryDocument.fromFile(DocumentFile file) {
    return LibraryDocument(
      id: file.id,
      file: file,
      title: _removeSupportedExtension(file.name),
      pages: null,
      metadata: const {},
      addedAt: file.createdAt,
    );
  }

  LibraryDocument copyWith({
    String? id,
    DocumentFile? file,
    String? title,
    int? pages,
    Map<String, dynamic>? metadata,
    DateTime? addedAt,
  }) {
    return LibraryDocument(
      id: id ?? this.id,
      file: file ?? this.file,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      metadata: metadata ?? this.metadata,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': file.path,
      'addedAt': addedAt.toIso8601String(),
      'pages': pages,
      'metadata': metadata,
    };
  }

  factory LibraryDocument.fromJson(Map<String, dynamic> json, DocumentFile file) {
    final rawMetadata = json['metadata'];
    return LibraryDocument(
      id: json['id']?.toString() ?? file.id,
      file: file,
      title: json['title']?.toString() ?? _removeSupportedExtension(file.name),
      pages: (json['pages'] as num?)?.toInt(),
      metadata: rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata) : const {},
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ?? file.createdAt,
    );
  }

  static String _removeSupportedExtension(String name) {
    return name.replaceFirst(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '');
  }
}
