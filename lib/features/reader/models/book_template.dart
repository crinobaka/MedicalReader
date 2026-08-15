class BookTemplate {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? author;
  final Map<String, dynamic> data;

  const BookTemplate({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    required this.data,
  });

  factory BookTemplate.fromJson(Map<String, dynamic> json) {
    return BookTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String?,
      author: json['author'] as String?,
      data: Map<String, dynamic>.from(
        json['data'] as Map? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      'data': data,
    };
  }
}