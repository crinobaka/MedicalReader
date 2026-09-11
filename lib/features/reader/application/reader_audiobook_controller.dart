import 'dart:async';

import '../domain/models/reader_audiobook.dart';

class ReaderAudiobookController {
  ReaderAudiobookController({
    ReaderAudiobookService? service,
    this.segments = const [],
  }) : _service = service;

  final ReaderAudiobookService? _service;
  final List<ReaderSubtitleSegment> segments;
  ReaderAudiobookState state = const ReaderAudiobookState();
  Timer? _ticker;

  Future<void> play() async {
    if (_service == null) return;
    await _service.play();
    state = state.copyWith(playing: true);
    _startTicker();
  }

  Future<void> pause() async {
    await _service?.pause();
    state = state.copyWith(playing: false);
    _ticker?.cancel();
  }

  Future<void> seek(Duration position) async {
    await _service?.seek(position);
    _setPosition(position);
  }

  Future<void> setSpeed(double speed) async {
    final value = speed.clamp(.5, 3.0).toDouble();
    await _service?.setSpeed(value);
    state = state.copyWith(speed: value);
  }

  ReaderSubtitleSegment? get activeSegment => state.activeSegment == null
      ? null
      : segments.elementAtOrNull(state.activeSegment!);

  void _setPosition(Duration position) {
    var active;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].contains(position)) {
        active = i;
        break;
      }
    }
    state = state.copyWith(position: position, activeSegment: active);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _setPosition(state.position + const Duration(milliseconds: 250));
    });
  }

  void dispose() => _ticker?.cancel();
}

extension<T> on List<T> {
  T? elementAtOrNull(int index) => index < 0 || index >= length ? null : this[index];
}
