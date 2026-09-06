import 'reader_locator.dart';

class ReaderPosition {
  final ReaderLocator locator;
  final double progress;

  const ReaderPosition({
    required this.locator,
    this.progress = 0,
  });

  ReaderPosition copyWith({
    ReaderLocator? locator,
    double? progress,
  }) {
    return ReaderPosition(
      locator: locator ?? this.locator,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() => {
    'locator': locator.toJson(),
    'progress': progress,
  };

  factory ReaderPosition.fromJson(Map<String, dynamic> json) {
    return ReaderPosition(
      locator: ReaderLocator.fromJson(
        Map<String, dynamic>.from(json['locator'] as Map),
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
    );
  }
}
