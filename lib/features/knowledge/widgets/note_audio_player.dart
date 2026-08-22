import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Note 中独立的录音播放器。
///
/// 支持播放/暂停、拖动进度、当前时间和总时长。
class NoteAudioPlayer extends StatefulWidget {
  final String filePath;

  const NoteAudioPlayer({super.key, required this.filePath});

  @override
  State<NoteAudioPlayer> createState() => _NoteAudioPlayerState();
}

class _NoteAudioPlayerState extends State<NoteAudioPlayer> {
  late final AudioPlayer _player;
  StreamSubscription<Duration?>? _durationSubscription;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _durationSubscription = _player.durationStream.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setFilePath(widget.filePath);
    } catch (_) {}
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration ?? Duration.zero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () => playing ? _player.pause() : _player.play(),
                    ),
                    Text(_format(_player.position)),
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final max = duration.inMilliseconds.toDouble();
                          return Slider(
                            value: max <= 0
                                ? 0
                                : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                            max: max <= 0 ? 1 : max,
                            onChanged: max <= 0
                                ? null
                                : (value) => _player.seek(Duration(milliseconds: value.round())),
                          );
                        },
                      ),
                    ),
                    Text(_format(duration)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
