import 'dart:convert';

enum CropTemplate { single, doubleColumn, tripleColumn, custom, bookTemplate }

enum CropLayout { horizontal, grid }

/// PDF 页面裁剪配置。所有坐标均为 0..1 的归一化坐标。
class CropConfiguration {
  final CropTemplate template;
  final CropLayout layout;
  final List<CropRegion> regions;
  final int? pageStart;
  final int? pageEnd;
  final bool inheritPrevious;
  final CropAdjustment adjustment;
  final String? sourceDocumentId;
  final String? temporarySessionId;
  final DateTime createdAt;

  const CropConfiguration({
    this.template = CropTemplate.single,
    this.layout = CropLayout.horizontal,
    this.regions = const [],
    this.pageStart,
    this.pageEnd,
    this.inheritPrevious = false,
    this.adjustment = const CropAdjustment(),
    this.sourceDocumentId,
    this.temporarySessionId,
    required this.createdAt,
  });

  factory CropConfiguration.initial({String? sourceDocumentId}) {
    return CropConfiguration(
      sourceDocumentId: sourceDocumentId,
      createdAt: DateTime.now(),
    );
  }

  factory CropConfiguration.fromJson(Map<String, dynamic> json) {
    final rawStart = (json['pageStart'] as num?)?.toInt();
    final rawEnd = (json['pageEnd'] as num?)?.toInt();
    final start = rawStart != null && rawStart > 0 ? rawStart : null;
    final end = rawEnd != null && rawEnd > 0 ? rawEnd : null;

    return CropConfiguration(
      template: CropTemplate.values.firstWhere(
        (item) => item.name == json['template'],
        orElse: () => CropTemplate.single,
      ),
      layout: CropLayout.values.firstWhere(
        (item) => item.name == json['layout'],
        orElse: () => CropLayout.horizontal,
      ),
      regions: (json['regions'] as List?)
              ?.whereType<Map>()
              .map((item) => CropRegion.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          const [],
      pageStart: start != null && end != null && start > end ? end : start,
      pageEnd: start != null && end != null && start > end ? start : end,
      inheritPrevious: json['inheritPrevious'] == true,
      adjustment: CropAdjustment.fromJson(
        Map<String, dynamic>.from(json['adjustment'] as Map? ?? const {}),
      ),
      sourceDocumentId: json['sourceDocumentId'] as String?,
      temporarySessionId: json['temporarySessionId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template.name,
        'layout': layout.name,
        'regions': regions.map((region) => region.clamp().toJson()).toList(),
        if (pageStart != null) 'pageStart': pageStart,
        if (pageEnd != null) 'pageEnd': pageEnd,
        'inheritPrevious': inheritPrevious,
        'adjustment': adjustment.toJson(),
        if (sourceDocumentId != null) 'sourceDocumentId': sourceDocumentId,
        if (temporarySessionId != null) 'temporarySessionId': temporarySessionId,
        'createdAt': createdAt.toIso8601String(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// 用于页面缓存键，确保裁剪参数变化后不会复用旧图像。
  String get cacheKey => jsonEncode(toJson());

  CropConfiguration copyWith({
    CropTemplate? template,
    CropLayout? layout,
    List<CropRegion>? regions,
    int? pageStart,
    int? pageEnd,
    bool? inheritPrevious,
    CropAdjustment? adjustment,
    String? sourceDocumentId,
    String? temporarySessionId,
    DateTime? createdAt,
  }) {
    return CropConfiguration(
      template: template ?? this.template,
      layout: layout ?? this.layout,
      regions: regions ?? this.regions,
      pageStart: pageStart ?? this.pageStart,
      pageEnd: pageEnd ?? this.pageEnd,
      inheritPrevious: inheritPrevious ?? this.inheritPrevious,
      adjustment: adjustment ?? this.adjustment,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      temporarySessionId: temporarySessionId ?? this.temporarySessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CropRegion {
  final double x;
  final double y;
  final double width;
  final double height;

  const CropRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory CropRegion.fromJson(Map<String, dynamic> json) {
    return CropRegion(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 1,
    ).clamp();
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  CropRegion clamp() {
    final nextX = x.clamp(0.0, 1.0).toDouble();
    final nextY = y.clamp(0.0, 1.0).toDouble();
    final nextWidth = width.clamp(0.001, 1.0 - nextX).toDouble();
    final nextHeight = height.clamp(0.001, 1.0 - nextY).toDouble();

    return CropRegion(
      x: nextX,
      y: nextY,
      width: nextWidth,
      height: nextHeight,
    );
  }

  CropRegion adjust(CropAdjustment adjustment) {
    return CropRegion(
      x: x + adjustment.left,
      y: y + adjustment.top,
      width: width - adjustment.left - adjustment.right,
      height: height - adjustment.top - adjustment.bottom,
    ).clamp();
  }
}

/// 当前裁剪基础上的增量调整。
/// 正值表示从对应边继续向内裁，负值表示向外放宽。
class CropAdjustment {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const CropAdjustment({
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });

  factory CropAdjustment.fromJson(Map<String, dynamic> json) {
    return CropAdjustment(
      left: (json['left'] as num?)?.toDouble() ?? 0,
      right: (json['right'] as num?)?.toDouble() ?? 0,
      top: (json['top'] as num?)?.toDouble() ?? 0,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'left': left,
        'right': right,
        'top': top,
        'bottom': bottom,
      };
}
