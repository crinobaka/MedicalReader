class ReaderStatistics {
  final Duration readingTime;
  final int charactersRead;
  final int sessions;
  final DateTime? lastReadAt;
  final int? totalCharacters;

  const ReaderStatistics({
    this.readingTime = Duration.zero,
    this.charactersRead = 0,
    this.sessions = 0,
    this.lastReadAt,
    this.totalCharacters,
  });

  double get charactersPerMinute {
    final minutes = readingTime.inSeconds / 60;
    return minutes <= 0 ? 0 : charactersRead / minutes;
  }

  double? get progress => totalCharacters == null || totalCharacters == 0
      ? null
      : (charactersRead / totalCharacters!).clamp(0.0, 1.0);

  ReaderStatistics record({
    required Duration elapsed,
    required int characters,
    DateTime? at,
  }) => ReaderStatistics(
        readingTime: readingTime + elapsed,
        charactersRead: charactersRead + characters,
        sessions: sessions + 1,
        lastReadAt: at ?? DateTime.now(),
        totalCharacters: totalCharacters,
      );

  Map<String, dynamic> toJson() => {
        'readingTimeSeconds': readingTime.inSeconds,
        'charactersRead': charactersRead,
        'sessions': sessions,
        if (lastReadAt != null) 'lastReadAt': lastReadAt!.toIso8601String(),
        if (totalCharacters != null) 'totalCharacters': totalCharacters,
      };

  factory ReaderStatistics.fromJson(Map<String, dynamic> json) => ReaderStatistics(
        readingTime: Duration(seconds: (json['readingTimeSeconds'] as num?)?.toInt() ?? 0),
        charactersRead: (json['charactersRead'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        lastReadAt: DateTime.tryParse(json['lastReadAt']?.toString() ?? ''),
        totalCharacters: (json['totalCharacters'] as num?)?.toInt(),
      );
}
