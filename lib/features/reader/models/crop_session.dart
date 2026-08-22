import 'dart:convert';

/// 一次裁剪操作的临时会话。
/// 原 PDF 永远不修改，裁剪结果写入书籍目录下的 temporary/crop-session-*。
class CropSession {
  final String id;
  final String sourceDocumentId;
  final String template;
  final List<Map<String, dynamic>> regions;
  final int? pageStart;
  final int? pageEnd;
  final DateTime createdAt;
  final String directoryPath;

  const CropSession({
    required this.id,
    required this.sourceDocumentId,
    required this.template,
    required this.regions,
    required this.pageStart,
    required this.pageEnd,
    required this.createdAt,
    required this.directoryPath,
  });

  factory CropSession.fromJson(Map<String, dynamic> json) {
    return CropSession(
      id: json['temporarySessionId'] as String? ?? '',
      sourceDocumentId: json['sourceDocumentId'] as String? ?? '',
      template: json['template'] as String? ?? 'single',
      regions: (json['regions'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      pageStart: (json['pageStart'] as num?)?.toInt(),
      pageEnd: (json['pageEnd'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      directoryPath: json['directoryPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'temporarySessionId': id,
        'sourceDocumentId': sourceDocumentId,
        'template': template,
        'regions': regions,
        if (pageStart != null) 'pageStart': pageStart,
        if (pageEnd != null) 'pageEnd': pageEnd,
        'createdAt': createdAt.toIso8601String(),
        'directoryPath': directoryPath,
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}
