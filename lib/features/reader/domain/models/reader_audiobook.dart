class ReaderSubtitleSegment {
  final Duration start;
  final Duration end;
  final String text;
  final String? href;
  final int? startOffset;
  final int? endOffset;

  const ReaderSubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
    this.href,
    this.startOffset,
    this.endOffset,
  });

  bool contains(Duration position) => position >= start && position <= end;
}

class ReaderAudiobookState {
  final bool playing;
  final Duration position;
  final Duration? duration;
  final double speed;
  final int? activeSegment;

  const ReaderAudiobookState({
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1,
    this.activeSegment,
  });

  ReaderAudiobookState copyWith({
    bool? playing,
    Duration? position,
    Duration? duration,
    double? speed,
    int? activeSegment,
  }) => ReaderAudiobookState(
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        activeSegment: activeSegment ?? this.activeSegment,
      );
}

abstract interface class ReaderAudiobookService {
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
}
