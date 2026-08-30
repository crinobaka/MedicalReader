import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../models/note_document.dart';
import '../services/note_renderer.dart';
import 'note_audio_player.dart';

/// Note 预览唯一入口：正文按格式渲染，附件按类型渲染。
class NoteContentPreview extends StatelessWidget {
  final NoteDocument note;
  final String? attachmentBasePath;

  const NoteContentPreview({
    super.key,
    required this.note,
    this.attachmentBasePath,
  });

  @override
  Widget build(BuildContext context) {
    final audio = <String>[];
    final images = <String>[];
    for (final attachment in note.attachments) {
      final lower = attachment.toLowerCase();
      if (lower.endsWith('.wav') || lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.ogg')) {
        audio.add(attachment);
      } else {
        images.add(attachment);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        NoteRenderer().build(context, note),
        for (final path in images) _AttachmentImage(path: _resolve(path)),
        for (final path in audio) NoteAudioPlayer(filePath: _resolve(path)),
      ],
    );
  }

  String _resolve(String path) {
    if (path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) return path;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (attachmentBasePath == null) return path;
    final relative = path.startsWith('attachments/') ? path.substring('attachments/'.length) : path;
    String fullpath = join(attachmentBasePath!, relative);
    return File(fullpath).path;
  }
}

class _AttachmentImage extends StatelessWidget {
  final String path;
  const _AttachmentImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http://') || path.startsWith('https://')) return Padding(padding: const EdgeInsets.only(top: 12), child: Image.network(path));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Image.file(File(path), errorBuilder: (_, _, _) => Text('无法加载附件：$path')),
    );
  }
}
