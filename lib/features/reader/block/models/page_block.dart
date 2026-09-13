import 'dart:math' as math;

/// A virtual reading viewport on one original PDF page.
///
/// Coordinates are normalized against the original page (0..1). The original
/// PDF page index remains the only user-visible page identity.
class PageBlock {
  const PageBlock({
    required this.docId,
    required this.pageIndex,
    required this.blockIndex,
    required this.rect,
    required this.order,
    required this.source,
    this.scrollPercent = 0,
  });

  final String docId;
  final int pageIndex;
  final int blockIndex;
  final NormalizedRect rect;
  final int order;
  final PageBlockSource source;
  final double scrollPercent;

  PageBlock copyWith({
    int? blockIndex,
    NormalizedRect? rect,
    int? order,
    PageBlockSource? source,
    double? scrollPercent,
  }) => PageBlock(
        docId: docId,
        pageIndex: pageIndex,
        blockIndex: blockIndex ?? this.blockIndex,
        rect: rect ?? this.rect,
        order: order ?? this.order,
        source: source ?? this.source,
        scrollPercent: (scrollPercent ?? this.scrollPercent).clamp(0, 1),
      );

  Map<String, dynamic> toJson() => {
        'docId': docId,
        'pageIndex': pageIndex,
        'blockIndex': blockIndex,
        'rect': rect.toJson(),
        'order': order,
        'source': source.name,
        'scrollPercent': scrollPercent,
      };

  factory PageBlock.fromJson(Map<String, dynamic> json) => PageBlock(
        docId: json['docId']?.toString() ?? '',
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        blockIndex: (json['blockIndex'] as num?)?.toInt() ?? 0,
        rect: NormalizedRect.fromJson(json['rect']),
        order: (json['order'] as num?)?.toInt() ?? 0,
        source: PageBlockSource.values.firstWhere(
          (v) => v.name == json['source'],
          orElse: () => PageBlockSource.manual,
        ),
        scrollPercent: ((json['scrollPercent'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      );

  @override
  String toString() => '$pageIndex(${blockIndex + 1})';
}

enum PageBlockSource { defaultBlock, manual }

class NormalizedRect {
  const NormalizedRect({required this.x, required this.y, required this.width, required this.height});

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  NormalizedRect normalized() {
    final left = x.clamp(0.0, 1.0).toDouble();
    final top = y.clamp(0.0, 1.0).toDouble();
    final rightEdge = right.clamp(0.0, 1.0).toDouble();
    final bottomEdge = bottom.clamp(0.0, 1.0).toDouble();
    return NormalizedRect(
      x: math.min(left, rightEdge),
      y: math.min(top, bottomEdge),
      width: (rightEdge - left).abs(),
      height: (bottomEdge - top).abs(),
    );
  }

  bool contains(double px, double py) =>
      px >= x && px <= right && py >= y && py <= bottom;

  bool containsRect(NormalizedRect other) =>
      other.x >= x && other.right <= right && other.y >= y && other.bottom <= bottom;

  Map<String, double> toJson() => {'x': x, 'y': y, 'w': width, 'h': height};

  factory NormalizedRect.fromJson(dynamic value) {
    if (value is Map) {
      return NormalizedRect(
        x: (value['x'] as num?)?.toDouble() ?? 0,
        y: (value['y'] as num?)?.toDouble() ?? 0,
        width: (value['w'] as num?)?.toDouble() ?? 1,
        height: (value['h'] as num?)?.toDouble() ?? 1,
      ).normalized();
    }
    if (value is List && value.length >= 4) {
      return NormalizedRect(
        x: (value[0] as num).toDouble(),
        y: (value[1] as num).toDouble(),
        width: (value[2] as num).toDouble(),
        height: (value[3] as num).toDouble(),
      ).normalized();
    }
    return const NormalizedRect(x: 0, y: 0, width: 1, height: 1);
  }
}
