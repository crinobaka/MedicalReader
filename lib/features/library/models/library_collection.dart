class LibraryCollection {
  final String id;
  final String name;
  final DateTime createdAt;

  const LibraryCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LibraryCollection.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) throw const FormatException('Invalid library collection');
    return LibraryCollection(
      id: id,
      name: name,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}