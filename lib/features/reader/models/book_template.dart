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

  factory BookTemplate.fromJson(
    Map<String, dynamic> json,
  ) {
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
  // 用途：让 BookTemplateMatcher 根据文档信息匹配模板。
  // ------------------------------------------------------------
  Map<String, dynamic> get metadata {
    return Map<String, dynamic>.from(
      data['metadata'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 模板别名
  // 用途：没有明确模板 ID 时，根据书名进行匹配。
  // ------------------------------------------------------------
  List<String> get aliases {
    return (data['aliases'] as List?)
            ?.whereType<String>()
            .toList() ??
        const [];
  }

  // ------------------------------------------------------------
  // 模板默认配置
  //
  // 注意：
  // 这里的配置全部属于“默认值”。
  // 当前书籍的目录.book.json 可以覆盖这些值。
  // ------------------------------------------------------------
  Map<String, dynamic> get defaults {
    return Map<String, dynamic>.from(
      data['defaults'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 默认 PDF ↔ 书籍页码映射配置
  // ------------------------------------------------------------
  Map<String, dynamic> get bookPageMapping {
    return Map<String, dynamic>.from(
      defaults['bookPageMapping'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 默认搜索上下文配置
  // ------------------------------------------------------------
  Map<String, dynamic> get searchContext {
    return Map<String, dynamic>.from(
      defaults['searchContext'] as Map? ?? const {},
    );
  }

  // ------------------------------------------------------------
  // 默认裁剪配置。
  //
  // Commit 4：裁剪配置同样属于模板默认值，具体书籍可以在
  // 目录.book.json 中覆盖。
  // ------------------------------------------------------------
  Map<String, dynamic> get crop {
    return Map<String, dynamic>.from(
      defaults['crop'] as Map? ?? const {},
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
