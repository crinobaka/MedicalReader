import 'dart:convert';

/// 当前书籍自己的配置文件。
///
/// 对应书籍目录中的：
///
/// 原文.pdf
/// 目录.book.json
///
/// BookTemplate 是“默认值”，
/// BookManifest 是“这一本书自己的数据和覆盖配置”。
class BookManifest {
  final int version;

  final String? templateId;

  final Map<String, dynamic> metadata;

  final Map<String, dynamic> bookPageMapping;

  final Map<String, dynamic> searchContext;

  final List<Map<String, dynamic>> bookTree;

  const BookManifest({
    this.version = 1,
    this.templateId,
    this.metadata = const {},
    this.bookPageMapping = const {},
    this.searchContext = const {},
    this.bookTree = const [],
  });

  factory BookManifest.fromJson(Map<String, dynamic> json) {
    return BookManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      templateId: _readString(json['templateId']),
      metadata: _readMap(json['metadata']),
      bookPageMapping: _readMap(json['bookPageMapping']),
      searchContext: _readMap(json['searchContext']),
      bookTree: _readNodeList(json['bookTree']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      if (templateId != null) 'templateId': templateId,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (bookPageMapping.isNotEmpty)
        'bookPageMapping': bookPageMapping,
      if (searchContext.isNotEmpty)
        'searchContext': searchContext,
      if (bookTree.isNotEmpty) 'bookTree': bookTree,
    };
  }

  String encode() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  static String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _readNodeList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }
}