import 'dart:convert';

import '../reader/domain/models/reader_locator.dart';
import 'reader_ink_stroke.dart';

enum ReaderAnnotationType { highlight, note, bookmark, tag, ink }

enum ReaderNoteFormat { markdown, markdownHtml }

class ReaderAnnotation {
  final String id;
  final String bookId;
  final int pageIndex;
  final ReaderLocator? locator;
  final ReaderAnnotationType type;
  final String content;
  final String title;
  final ReaderNoteFormat noteFormat;
  final List<double> rect;
  final List<String> attachments;
  final ReaderInkStroke? inkStroke;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReaderAnnotation({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    this.locator,
    required this.type,
    this.content = '',
    this.title = '',
    this.noteFormat = ReaderNoteFormat.markdown,
    this.rect = const [],
    this.attachments = const [],
    this.inkStroke,
    required this.createdAt,
    required this.updatedAt,
  });

  ReaderAnnotation copyWith({
    String? id,
    String? bookId,
    int? pageIndex,
    ReaderLocator? locator,
    ReaderAnnotationType? type,
    String? content,
    String? title,
    ReaderNoteFormat? noteFormat,
    List<double>? rect,
    List<String>? attachments,
    ReaderInkStroke? inkStroke,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReaderAnnotation(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    pageIndex: pageIndex ?? this.pageIndex,
    locator: locator ?? this.locator,
    type: type ?? this.type,
    content: content ?? this.content,
    title: title ?? this.title,
    noteFormat: noteFormat ?? this.noteFormat,
    rect: rect ?? this.rect,
    attachments: attachments ?? this.attachments,
    inkStroke: inkStroke ?? this.inkStroke,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'pageIndex': pageIndex,
    if (locator != null) 'locator': locator!.toJson(),
    'type': type.name,
    'content': content,
    'title': title,
    'noteFormat': noteFormat.name,
    'rect': rect,
    'attachments': attachments,
    if (inkStroke != null) 'inkStroke': inkStroke!.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReaderAnnotation.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'bookmark';
    final noteFormatName = json['noteFormat']?.toString() ?? 'markdown';
    final rawInk = json['inkStroke'];
    final rawLocator = json['locator'];
    return ReaderAnnotation(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      locator: rawLocator is Map
          ? ReaderLocator.fromJson(Map<String, dynamic>.from(rawLocator))
          : null,
      type: ReaderAnnotationType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => ReaderAnnotationType.bookmark,
      ),
      content: json['content']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      noteFormat: ReaderNoteFormat.values.firstWhere(
        (value) => value.name == noteFormatName,
        orElse: () => ReaderNoteFormat.markdown,
      ),
      rect: json['rect'] is List
          ? (json['rect'] as List).whereType<num>().map((v) => v.toDouble()).toList()
          : const [],
      attachments: json['attachments'] is List
          ? (json['attachments'] as List).map((v) => v.toString()).toList()
          : const [],
      inkStroke: rawInk is Map
          ? ReaderInkStroke.fromJson(Map<String, dynamic>.from(rawInk))
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}
