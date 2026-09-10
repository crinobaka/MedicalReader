import 'reader_locator.dart';

class ReaderPosition {
  final ReaderLocator? locator;
  final double progress;
  final int? spineIndex;
  final String? href;
  final int? characterOffset;

  const ReaderPosition({
    this.locator,
    this.progress = 0,
    this.spineIndex,
    this.href,
    this.characterOffset,
  });

  ReaderPosition copyWith({
    ReaderLocator? locator,
    double? progress,
    int? spineIndex,
    String? href,
    int? characterOffset,
  }) {
    return ReaderPosition(
      locator: locator ?? this.locator,
      progress: progress ?? this.progress,
      spineIndex: spineIndex ?? this.spineIndex,
      href: href ?? this.href,
      characterOffset: characterOffset ?? this.characterOffset,
    );
  }

  Map<String, dynamic> toJson() => {
    if (locator != null) 'locator': locator!.toJson(),
    'progress': progress,
    if (spineIndex != null) 'spineIndex': spineIndex,
    if (href != null) 'href': href,
    if (characterOffset != null) 'characterOffset': characterOffset,
  };

  factory ReaderPosition.fromJson(Map<String, dynamic> json) {
    final locatorJson = json['locator'];
    return ReaderPosition(
      locator: locatorJson is Map
          ? ReaderLocator.fromJson(Map<String, dynamic>.from(locatorJson))
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      spineIndex: (json['spineIndex'] as num?)?.toInt(),
      href: json['href'] as String?,
      characterOffset: (json['characterOffset'] as num?)?.toInt(),
    );
  }
}
