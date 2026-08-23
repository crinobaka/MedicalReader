import 'dart:convert';

enum CropTemplate { single, doubleColumn, tripleColumn, custom, bookTemplate }
enum CropLayout { horizontal, grid }
enum CropPageBasis { pdf, book }

class CropPageRange {
  final int start;
  final int end;

  const CropPageRange({required this.start, required this.end});

  factory CropPageRange.fromJson(Map<String, dynamic> json) {
    final rawStart = (json['start'] as num?)?.toInt() ?? 1;
    final rawEnd = (json['end'] as num?)?.toInt() ?? rawStart;
    final start = rawStart > 0 ? rawStart : 1;
    final end = rawEnd > 0 ? rawEnd : start;
    return CropPageRange(start: start <= end ? start : end, end: start <= end ? end : start);
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
  bool contains(int pageNumber) => pageNumber >= start && pageNumber <= end;
  String get label => start == end ? '$start' : '$start-$end';
}

class CropConfiguration {
  final CropTemplate template;
  final CropLayout layout;
  final List<CropRegion> regions;
  final int? pageStart;
  final int? pageEnd;
  final CropPageBasis pageBasis;
  final List<CropPageRange> pageRanges;
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
    this.pageBasis = CropPageBasis.pdf,
    this.pageRanges = const [],
    this.inheritPrevious = false,
    this.adjustment = const CropAdjustment(),
    this.sourceDocumentId,
    this.temporarySessionId,
    required this.createdAt,
  });

  factory CropConfiguration.initial({String? sourceDocumentId}) => CropConfiguration(sourceDocumentId: sourceDocumentId, createdAt: DateTime.now());

  factory CropConfiguration.fromJson(Map<String, dynamic> json) {
    final rawStart = (json['pageStart'] as num?)?.toInt();
    final rawEnd = (json['pageEnd'] as num?)?.toInt();
    final start = rawStart != null && rawStart > 0 ? rawStart : null;
    final end = rawEnd != null && rawEnd > 0 ? rawEnd : null;
    final rawRanges = json['pageRanges'];
    final ranges = rawRanges is List
        ? rawRanges.whereType<Map>().map((item) => CropPageRange.fromJson(Map<String, dynamic>.from(item))).toList()
        : const <CropPageRange>[];

    return CropConfiguration(
      template: CropTemplate.values.firstWhere((item) => item.name == json['template'], orElse: () => CropTemplate.single),
      layout: CropLayout.values.firstWhere((item) => item.name == json['layout'], orElse: () => CropLayout.horizontal),
      regions: (json['regions'] as List?)?.whereType<Map>().map((item) => CropRegion.fromJson(Map<String, dynamic>.from(item))).toList() ?? const [],
      pageStart: start != null && end != null && start > end ? end : start,
      pageEnd: start != null && end != null && start > end ? start : end,
      pageBasis: CropPageBasis.values.firstWhere((item) => item.name == json['pageBasis'], orElse: () => CropPageBasis.pdf),
      pageRanges: ranges,
      inheritPrevious: json['inheritPrevious'] == true,
      adjustment: CropAdjustment.fromJson(Map<String, dynamic>.from(json['adjustment'] as Map? ?? const {})),
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
        'pageBasis': pageBasis.name,
        if (pageRanges.isNotEmpty) 'pageRanges': pageRanges.map((range) => range.toJson()).toList(),
        'inheritPrevious': inheritPrevious,
        'adjustment': adjustment.toJson(),
        if (sourceDocumentId != null) 'sourceDocumentId': sourceDocumentId,
        if (temporarySessionId != null) 'temporarySessionId': temporarySessionId,
        'createdAt': createdAt.toIso8601String(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
  String get cacheKey => jsonEncode(toJson());

  CropConfiguration copyWith({
    CropTemplate? template,
    CropLayout? layout,
    List<CropRegion>? regions,
    int? pageStart,
    int? pageEnd,
    CropPageBasis? pageBasis,
    List<CropPageRange>? pageRanges,
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
      pageBasis: pageBasis ?? this.pageBasis,
      pageRanges: pageRanges ?? this.pageRanges,
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
  final bool excluded;

  const CropRegion({required this.x, required this.y, required this.width, required this.height, this.excluded = false});

  factory CropRegion.fromJson(Map<String, dynamic> json) => CropRegion(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 1,
        height: (json['height'] as num?)?.toDouble() ?? 1,
        excluded: json['excluded'] == true,
      ).clamp();

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'width': width, 'height': height, if (excluded) 'excluded': true};

  CropRegion clamp() {
    final nextX = x.clamp(0.0, 0.999999).toDouble();
    final nextY = y.clamp(0.0, 0.999999).toDouble();
    final maxWidth = (1.0 - nextX).clamp(0.001, 1.0).toDouble();
    final maxHeight = (1.0 - nextY).clamp(0.001, 1.0).toDouble();
    final nextWidth = width.clamp(0.001, maxWidth).toDouble();
    final nextHeight = height.clamp(0.001, maxHeight).toDouble();
    return CropRegion(x: nextX, y: nextY, width: nextWidth, height: nextHeight, excluded: excluded);
  }

  CropRegion copyWith({double? x, double? y, double? width, double? height, bool? excluded}) =>
      CropRegion(x: x ?? this.x, y: y ?? this.y, width: width ?? this.width, height: height ?? this.height, excluded: excluded ?? this.excluded).clamp();

  CropRegion adjust(CropAdjustment adjustment) => CropRegion(
        x: x + adjustment.left,
        y: y + adjustment.top,
        width: width - adjustment.left - adjustment.right,
        height: height - adjustment.top - adjustment.bottom,
        excluded: excluded,
      ).clamp();
}

class CropAdjustment {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const CropAdjustment({this.left = 0, this.right = 0, this.top = 0, this.bottom = 0});

  factory CropAdjustment.fromJson(Map<String, dynamic> json) => CropAdjustment(
        left: (json['left'] as num?)?.toDouble() ?? 0,
        right: (json['right'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'left': left, 'right': right, 'top': top, 'bottom': bottom};
}
