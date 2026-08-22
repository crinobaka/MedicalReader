import '../../../../core/file_manager/models/document_file.dart';

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

  factory LibraryDocument.fromFile(
    DocumentFile file,
  ) {
    return LibraryDocument(
      // 使用 DocumentFile 的稳定 ID。
      id: file.id,

      file: file,

      title: _removePdfExtension(file.name),

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

  factory LibraryDocument.fromJson(
    Map<String, dynamic> json,
    DocumentFile file,
  ) {
    final rawMetadata = json['metadata'];

    return LibraryDocument(
      id: json['id']?.toString() ?? file.id,

      file: file,

      title: json['title']?.toString() ??
          _removePdfExtension(file.name),

      pages: (json['pages'] as num?)?.toInt(),

      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const {},

      addedAt:
          DateTime.tryParse(
                json['addedAt']?.toString() ?? '',
              ) ??
              file.createdAt,
    );
  }

  static String _removePdfExtension(
    String name,
  ) {
    return name.replaceFirst(
      RegExp(
        r'\.pdf$',
        caseSensitive: false,
      ),
      '',
    );
  }
}