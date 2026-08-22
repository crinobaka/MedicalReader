import 'dart:io';

import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'note_audio_player.dart';
import '../services/note_renderer.dart';

/// Note 预览层的唯一入口。
///
/// 正文由 NoteRenderer 按格式选择 Markdown/HTML renderer；
/// Audio 则作为独立附件 widget 渲染，不伪装成 Markdown 链接。
class NoteContentPreview extends StatelessWidget {
  final NoteDocument note;

  const NoteContentPreview({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final audio = <String>[];
    final otherAttachments = <String>[];

    for (final attachment in note.attachments) {
      final lower = attachment.toLowerCase();
      if (lower.endsWith('.wav') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.ogg')) {
        audio.add(attachment);
      } else {
        otherAttachments.add(attachment);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        NoteRenderer().build(context, note),
        for (final attachment in otherAttachments)
          _AttachmentImage(path: attachment),
        for (final path in audio)
          NoteAudioPlayer(filePath: _resolvePath(note, path)),
      ],
    );
  }

  String _resolvePath(NoteDocument note, String path) {
    if (path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
      return path;
    }
    // Attachment paths are resolved by the caller's document layer in the
    // production page. Keep relative references untouched here so the widget
    // remains storage-agnostic.
    return path;
  }
}

class _AttachmentImage extends StatelessWidget {
  final String path;

  const _AttachmentImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Image.network(path),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Image.file(
        File(path),
        errorBuilder: (_, __, ___) => Text('无法加载附件：$path'),
      ),
    );
  }
}
