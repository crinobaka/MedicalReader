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
enum ReaderAnnotationType { highlight, note, bookmark, tag }

/// 笔记正文格式。
///
/// markdown：普通 Markdown。
///
/// markdownHtml：Markdown + HTML。
///
/// markdown 包本身会把 Markdown 和 HTML 一起转换为 HTML，
/// 因此这里保存的是“用户选择的写作模式”，而不是另外维护两套正文。
enum ReaderNoteFormat { markdown, markdownHtml }

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
  /// note 保存 Markdown / Markdown+HTML 正文。
  /// tag 保存标签名称。
  final String content;

  /// 笔记标题。
  ///
  /// 只有 note 使用。
  /// 其他 Annotation 保持空字符串。
  final String title;

  /// 笔记正文格式。
  ///
  /// 只有 note 使用。
  final ReaderNoteFormat noteFormat;

  /// 高亮/选区在 PDF 页面中的坐标。
  final List<double> rect;

  /// 附件列表。
  ///
  /// 图片和录音都不直接塞进正文二进制数据。
  ///
  /// 正文中保存 Markdown 引用：
  ///
  /// ![图片](attachments/xxx.jpg)
  ///
  /// [录音](attachments/xxx.wav)
  ///
  /// 这样 Note 本身仍然是纯文本。
  final List<String> attachments;

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
    this.title = '',
    this.noteFormat = ReaderNoteFormat.markdown,
    this.rect = const [],
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ReaderAnnotation copyWith({
    String? id,
    String? bookId,
    int? pageIndex,
    ReaderAnnotationType? type,
    String? content,
    String? title,
    ReaderNoteFormat? noteFormat,
    List<double>? rect,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReaderAnnotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      content: content ?? this.content,
      title: title ?? this.title,
      noteFormat: noteFormat ?? this.noteFormat,
      rect: rect ?? this.rect,
      attachments: attachments ?? this.attachments,
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
      'title': title,
      'noteFormat': noteFormat.name,
      'rect': rect,
      'attachments': attachments,
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

    final noteFormatName = json['noteFormat']?.toString() ?? 'markdown';

    final noteFormat = ReaderNoteFormat.values.firstWhere(
      (value) => value.name == noteFormatName,
      orElse: () => ReaderNoteFormat.markdown,
    );

    final rawAttachments = json['attachments'];

    final attachments = rawAttachments is List
        ? rawAttachments
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList()
        : const <String>[];

    final rawRect = json['rect'];

    final rect = rawRect is List
        ? rawRect.whereType<num>().map((value) => value.toDouble()).toList()
        : const <double>[];

    return ReaderAnnotation(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      type: type,
      content: json['content']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      noteFormat: noteFormat,
      rect: rect,
      attachments: attachments,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String encode() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
