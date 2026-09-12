import 'package:flutter/material.dart';

import '../application/reader_audiobook_controller.dart';

class ReaderAudiobookBar extends StatefulWidget {
  const ReaderAudiobookBar({super.key, required this.controller});
  final ReaderAudiobookController controller;

  @override
  State<ReaderAudiobookBar> createState() => _ReaderAudiobookBarState();
}

class _ReaderAudiobookBarState extends State<ReaderAudiobookBar> {
  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final segment = widget.controller.activeSegment;
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
              tooltip: state.playing ? '暂停' : '播放',
              onPressed: () async {
                if (state.playing) {
                  await widget.controller.pause();
                } else {
                  await widget.controller.play();
                }
                if (mounted) setState(() {});
              },
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(child: Text(segment?.text ?? '有声伴读', maxLines: 2, overflow: TextOverflow.ellipsis)),
            PopupMenuButton<double>(
              initialValue: state.speed,
              tooltip: '播放速度',
              onSelected: (value) async {
                await widget.controller.setSpeed(value);
                if (mounted) setState(() {});
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: .75, child: Text('0.75×')),
                PopupMenuItem(value: 1, child: Text('1×')),
                PopupMenuItem(value: 1.25, child: Text('1.25×')),
                PopupMenuItem(value: 1.5, child: Text('1.5×')),
                PopupMenuItem(value: 2, child: Text('2×')),
              ],
            ),
          ]),
          if (state.duration != null)
            Slider(
              value: state.position.inMilliseconds.clamp(0, state.duration!.inMilliseconds).toDouble(),
              max: state.duration!.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (value) => setState(() => widget.controller.seek(Duration(milliseconds: value.round()))),
            ),
        ]),
      ),
    );
  }
}
