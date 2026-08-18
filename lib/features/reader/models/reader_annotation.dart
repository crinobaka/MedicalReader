import 'dart:convert';

/// MedicalReader 知识层中的统一用户标注模型。
///
/// 注意：
///
/// PDF 原文永远不修改。
///
/// 用户产生的内容全部保存到 Annotation Layer。
///
/// PDF
///   ↓
/// ReaderAnnotation
///   ↓
/// Reader View
///
/// v0.1 支持：
/// - highlight
/// - note
/// - bookmark
/// - tag
///
/// ink 暂时只保留数据类型，不提供手写 UI。
enum ReaderAnnotationType {
  highlight,
  note,
  bookmark,
  tag,
}

class ReaderAnnotation {
  /// 全局唯一标识。
  final String id;

  /// 所属书籍。
  final String bookId;

  /// PDF 页码，使用 0-based。
  final int pageIndex;

  /// 标注类型。
  final ReaderAnnotationType type;

  /// 用户内容。
  ///
  /// bookmark 可以为空。
  /// highlight 保存选中的文本。
  /// note 保存笔记正文。
  /// tag 保存标签名称。
  final String content;

  /// 高亮/选区在 PDF 页面中的坐标。
  ///
  /// 当前阶段可以为空。
  /// 后续接入 PDF text layer 后再填充。
  final List<double> rect;

  /// 创建时间。
  final DateTime createdAt;

  /// 最后修改时间。
  final DateTime updatedAt;

  const ReaderAnnotation({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    required this.type,
    this.content = '',
    this.rect = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ReaderAnnotation copyWith({
    String? id,
    String? bookId,
    int? pageIndex,
    ReaderAnnotationType? type,
    String? content,
    List<double>? rect,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReaderAnnotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      content: content ?? this.content,
      rect: rect ?? this.rect,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'pageIndex': pageIndex,
      'type': type.name,
      'content': content,
      'rect': rect,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReaderAnnotation.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'bookmark';

    final type = ReaderAnnotationType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => ReaderAnnotationType.bookmark,
    );

    final rawRect = json['rect'];

    final rect = rawRect is List
        ? rawRect
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList()
        : const <double>[];

    return ReaderAnnotation(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      type: type,
      content: json['content']?.toString() ?? '',
      rect: rect,
      createdAt: DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            json['updatedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  String encode() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}