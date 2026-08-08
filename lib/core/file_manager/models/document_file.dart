class DocumentFile {
  final String id;

  final String name;

  final String path;

  final int size;

  final DateTime createdAt;


  const DocumentFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
  });


  DocumentFile copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    DateTime? createdAt,
  }) {
    return DocumentFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}