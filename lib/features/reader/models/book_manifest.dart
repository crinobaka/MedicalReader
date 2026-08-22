import 'dart:convert';

import 'crop_configuration.dart';

/// 当前书籍自己的配置文件。
///
/// BookTemplate 是“默认值”，BookManifest 是“这一本书自己的数据和覆盖配置”。
class BookManifest {
  final int version;
  final String? templateId;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> bookPageMapping;
  final Map<String, dynamic> searchContext;
  final Map<String, dynamic> crop;
  final List<Map<String, dynamic>> bookTree;

  const BookManifest({
    this.version = 1,
    this.templateId,
    this.metadata = const {},
    this.bookPageMapping = const {},
    this.searchContext = const {},
    this.crop = const {},
    this.bookTree = const [],
  });

  factory BookManifest.fromJson(Map<String, dynamic> json) {
    return BookManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      templateId: _readString(json['templateId']),
      metadata: _readMap(json['metadata']),
      bookPageMapping: _readMap(json['bookPageMapping']),
      searchContext: _readMap(json['searchContext']),
      crop: _readMap(json['crop']),
      bookTree: _readNodeList(json['bookTree']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      if (templateId != null) 'templateId': templateId,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (bookPageMapping.isNotEmpty) 'bookPageMapping': bookPageMapping,
      if (searchContext.isNotEmpty) 'searchContext': searchContext,
      if (crop.isNotEmpty) 'crop': crop,
      if (bookTree.isNotEmpty) 'bookTree': bookTree,
    };
  }

  /// 已解析的裁剪配置；没有 crop 配置时返回 null。
  CropConfiguration? get cropConfiguration {
    if (crop.isEmpty) {
      return null;
    }

    return CropConfiguration.fromJson(crop);
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
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
