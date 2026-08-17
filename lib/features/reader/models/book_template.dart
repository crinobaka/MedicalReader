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

  // ------------------------------------------------------------
  // 模板 metadata
  // 用途：让 BookTemplateMatcher 根据文档 metadata 识别模板。
  // ------------------------------------------------------------
  Map<String, dynamic> get metadata {
    return Map<String, dynamic>.from(
      data['metadata'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 模板别名
  // 用途：当没有精确模板 ID 时，根据书名匹配模板。
  // ------------------------------------------------------------
  List<String> get aliases {
    return (data['aliases'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];
  }

  // ------------------------------------------------------------
  // PDF ↔ 书籍页码映射配置
  // ------------------------------------------------------------
  Map<String, dynamic> get bookPageMapping {
    return Map<String, dynamic>.from(
      data['bookPageMapping'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 搜索上下文配置
  // 用途：搜索结果显示章节、书籍页码和上下文。
  // ------------------------------------------------------------
  Map<String, dynamic> get searchContext {
    return Map<String, dynamic>.from(
      data['searchContext'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // BookTree
  // 用途：模板直接携带目录树时，由 BookTreeService 使用。
  // ------------------------------------------------------------
  List<Map<String, dynamic>> get bookTree {
    return (data['bookTree'] as List?)
            ?.whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList() ??
        const [];
  }

  // ------------------------------------------------------------
  // 外部 BookTree 文件
  // 用途：模板不直接携带目录，而是引用独立 JSON。
  // ------------------------------------------------------------
  String? get bookTreePath {
    final value = data['bookTreePath'];

    if (value is! String) {
      return null;
    }

    final path = value.trim();

    return path.isEmpty ? null : path;
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