import 'dart:convert';

import 'crop_configuration.dart';

/// 一次裁剪操作的临时会话。
/// 原 PDF 永远不修改，裁剪结果写入书籍目录下的 temporary/crop-session-*。
class CropSession {
  final String id;
  final String sourceDocumentId;
  final String template;
  final String layout;
  final String pageBasis;
  final List<Map<String, dynamic>> regions;
  final List<Map<String, dynamic>> pageRanges;
  final int? pageStart;
  final int? pageEnd;
  final bool inheritPrevious;
  final Map<String, dynamic> adjustment;
  final DateTime createdAt;
  final String directoryPath;

  const CropSession({
    required this.id,
    required this.sourceDocumentId,
    required this.template,
    required this.layout,
    required this.pageBasis,
    required this.regions,
    required this.pageRanges,
    required this.pageStart,
    required this.pageEnd,
    required this.inheritPrevious,
    required this.adjustment,
    required this.createdAt,
    required this.directoryPath,
  });

  factory CropSession.fromJson(Map<String, dynamic> json) {
    return CropSession(
      id: json['temporarySessionId'] as String? ?? '',
      sourceDocumentId: json['sourceDocumentId'] as String? ?? '',
      template: json['template'] as String? ?? 'single',
      layout: json['layout'] as String? ?? 'horizontal',
      pageBasis: json['pageBasis'] as String? ?? 'pdf',
      regions: (json['regions'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      pageRanges: (json['pageRanges'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      pageStart: (json['pageStart'] as num?)?.toInt(),
      pageEnd: (json['pageEnd'] as num?)?.toInt(),
      inheritPrevious: json['inheritPrevious'] == true,
      adjustment: Map<String, dynamic>.from(json['adjustment'] as Map? ?? const {}),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      directoryPath: json['directoryPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'temporarySessionId': id,
        'sourceDocumentId': sourceDocumentId,
        'template': template,
        'layout': layout,
        'pageBasis': pageBasis,
        'regions': regions,
        if (pageRanges.isNotEmpty) 'pageRanges': pageRanges,
        if (pageStart != null) 'pageStart': pageStart,
        if (pageEnd != null) 'pageEnd': pageEnd,
        'inheritPrevious': inheritPrevious,
        'adjustment': adjustment,
        'createdAt': createdAt.toIso8601String(),
        'directoryPath': directoryPath,
      };

  CropConfiguration toConfiguration() {
    return CropConfiguration.fromJson(toJson());
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}
