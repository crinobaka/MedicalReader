import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../models/note_document.dart';
import '../models/note_drawing.dart';
import '../services/note_drawing_storage.dart';
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
    final drawings = <String>[];
    for (final attachment in note.attachments) {
      final lower = attachment.toLowerCase();
      if (_isDrawingAttachment(attachment)) {
        drawings.add(attachment);
      } else if (lower.endsWith('.wav') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.ogg')) {
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
        for (final path in drawings) _AttachmentDrawing(path: _resolve(path)),
      ],
    );
  }

  bool _isDrawingAttachment(String path) {
    final lower = path.toLowerCase();
    if (!lower.endsWith('.json')) return false;
    return lower.contains('/note_drawings/') ||
        lower.contains('\\note_drawings\\') ||
        lower.contains('${Platform.pathSeparator}note_drawings${Platform.pathSeparator}');
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
        errorBuilder: (_, _, _) => Text('无法加载附件：$path'),
      ),
    );
  }
}

class _AttachmentDrawing extends StatelessWidget {
  final String path;
  const _AttachmentDrawing({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NoteDrawingLayer>(
      future: const NoteDrawingStorage().load(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final layer = snapshot.data;
        if (layer == null) {
          final error = snapshot.error;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('无法加载手绘：${error ?? '未知错误'}'),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: CustomPaint(
                painter: _NoteDrawingPainter(layer),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteDrawingPainter extends CustomPainter {
  final NoteDrawingLayer layer;
  const _NoteDrawingPainter(this.layer);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in layer.strokes) {
      if (stroke.points.isEmpty || stroke.tool == NoteDrawingTool.eraser) continue;
      final paint = Paint()
        ..color = Color(stroke.color).withOpacity(stroke.opacity.clamp(0.0, 1.0))
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final points = stroke.points.map((point) => point.toOffset(size)).toList();
      if (stroke.tool == NoteDrawingTool.line && points.length >= 2) {
        canvas.drawLine(points.first, points.last, paint);
      } else if (stroke.tool == NoteDrawingTool.rectangle && points.length >= 2) {
        canvas.drawRect(Rect.fromPoints(points.first, points.last), paint);
      } else if (stroke.tool == NoteDrawingTool.ellipse && points.length >= 2) {
        canvas.drawOval(Rect.fromPoints(points.first, points.last), paint);
      } else if (stroke.tool == NoteDrawingTool.polygon && points.length >= 2) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      } else if (points.length == 1) {
        canvas.drawCircle(points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoteDrawingPainter oldDelegate) => oldDelegate.layer != layer;
}
