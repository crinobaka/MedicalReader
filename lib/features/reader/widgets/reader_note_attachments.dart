import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ReaderNoteAttachments extends StatelessWidget {
  final String content;

  const ReaderNoteAttachments({
    super.key,
    required this.content,
  });

  List<_Attachment> _parse() {
    final result = <_Attachment>[];
    final seen = <String>{};

    void add(String type, String path) {
      final value = path.trim();
      if (value.isEmpty || !seen.add('$type:$value')) return;
      result.add(_Attachment(type: type, path: value));
    }

    final markdownImage = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');
    for (final match in markdownImage.allMatches(content)) {
      add('image', match.group(1)!);
    }

    final markdownAudio = RegExp(r'''\[录音\]\(([^)]+)\)''');
    for (final match in markdownAudio.allMatches(content)) {
      add('audio', match.group(1)!);
    }

    final htmlImage = RegExp(
      r'''<img[^>]+src=["\']([^"\']+)["\'][^>]*>''',
      caseSensitive: false,
    );
    for (final match in htmlImage.allMatches(content)) {
      add('image', match.group(1)!);
    }

    final htmlAudio = RegExp(
      r'''<(?:audio|source)[^>]+src=["\']([^"\']+)["\'][^>]*>''',
      caseSensitive: false,
    );
    for (final match in htmlAudio.allMatches(content)) {
      add('audio', match.group(1)!);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final attachments = _parse();
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          '附件',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AttachmentView(attachment: attachment),
          ),
      ],
    );
  }
}

class _Attachment {
  final String type;
  final String path;

  const _Attachment({required this.type, required this.path});
}

class _AttachmentView extends StatelessWidget {
  final _Attachment attachment;

  const _AttachmentView({required this.attachment});

  @override
  Widget build(BuildContext context) {
    if (attachment.type == 'image') {
      final file = File(_localPath(attachment.path));
      return Card(
        clipBehavior: Clip.antiAlias,
        child: file.existsSync()
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _MissingAttachment(path: attachment.path),
                ),
              )
            : _MissingAttachment(path: attachment.path),
      );
    }

    return _AudioAttachment(path: _localPath(attachment.path));
  }

  String _localPath(String value) {
    if (value.startsWith('file://')) {
      return Uri.parse(value).toFilePath();
    }
    return value;
  }
}

class _MissingAttachment extends StatelessWidget {
  final String path;

  const _MissingAttachment({required this.path});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.broken_image_outlined),
      title: const Text('附件无法读取'),
      subtitle: Text(
        path,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AudioAttachment extends StatefulWidget {
  final String path;

  const _AudioAttachment({required this.path});

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  late final AudioPlayer _player;
  Duration? _duration;
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _load();
  }

  Future<void> _load() async {
    try {
      final duration = await _player.setFilePath(widget.path);
      if (!mounted) return;
      setState(() {
        _duration = duration;
        _ready = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null || !_ready) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.audiotrack),
          title: Text(_error == null ? '正在加载录音…' : '录音无法读取'),
          subtitle: Text(
            widget.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final total = _duration ?? Duration.zero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      tooltip: playing ? '暂停' : '播放',
                      onPressed: () => playing ? _player.pause() : _player.play(),
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    );
                  },
                ),
                const Expanded(
                  child: Text(
                    '录音',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  initialData: Duration.zero,
                  builder: (context, snapshot) {
                    return Text('${_format(snapshot.data ?? Duration.zero)} / ${_format(total)}');
                  },
                ),
              ],
            ),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              initialData: Duration.zero,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final max = total.inMilliseconds.toDouble();
                final value = max <= 0
                    ? 0.0
                    : position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble();
                return Slider(
                  value: value,
                  max: max <= 0 ? 1.0 : max,
                  onChanged: max <= 0
                      ? null
                      : (next) => _player.seek(Duration(milliseconds: next.round())),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
