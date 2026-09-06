sealed class ReaderLocator {
  const ReaderLocator();

  Map<String, dynamic> toJson();

  factory ReaderLocator.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString();
    switch (kind) {
      case PdfReaderLocator.kind:
        return PdfReaderLocator.fromJson(json);
      case EpubReaderLocator.kind:
        return EpubReaderLocator.fromJson(json);
      default:
        throw FormatException('Unsupported reader locator: $kind');
    }
  }
}

final class PdfReaderLocator extends ReaderLocator {
  static const kind = 'pdf';

  final int pageIndex;
  final List<double> rect;

  const PdfReaderLocator({
    required this.pageIndex,
    this.rect = const [],
  });

  factory PdfReaderLocator.fromJson(Map<String, dynamic> json) {
    return PdfReaderLocator(
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      rect: json['rect'] is List
          ? (json['rect'] as List).whereType<num>().map((v) => v.toDouble()).toList(growable: false)
          : const [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'pageIndex': pageIndex,
    if (rect.isNotEmpty) 'rect': rect,
  };
}

final class EpubReaderLocator extends ReaderLocator {
  static const kind = 'epub';

  final String href;
  final String? fragment;
  final int? startOffset;
  final int? endOffset;
  final double? progress;

  const EpubReaderLocator({
    required this.href,
    this.fragment,
    this.startOffset,
    this.endOffset,
    this.progress,
  });

  factory EpubReaderLocator.fromJson(Map<String, dynamic> json) {
    return EpubReaderLocator(
      href: json['href']?.toString() ?? '',
      fragment: json['fragment']?.toString(),
      startOffset: (json['startOffset'] as num?)?.toInt(),
      endOffset: (json['endOffset'] as num?)?.toInt(),
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'href': href,
    if (fragment != null) 'fragment': fragment,
    if (startOffset != null) 'startOffset': startOffset,
    if (endOffset != null) 'endOffset': endOffset,
    if (progress != null) 'progress': progress,
  };
}
