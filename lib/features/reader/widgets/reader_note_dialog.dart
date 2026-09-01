import 'dart:io';

import 'package:flutter/material.dart';

import '../../knowledge/models/note_drawing.dart';
import '../../knowledge/services/note_drawing_storage.dart';
import '../../knowledge/widgets/note_drawing_editor.dart';
import '../models/reader_annotation.dart';
import 'reader_note_editor.dart';

class ReaderNoteDialog extends StatefulWidget {
  final ReaderAnnotation note;
  final String? documentDirectory;
  final Future<String?> Function()? onInsertImage;
  final Future<String?> Function()? onInsertAudio;

  const ReaderNoteDialog({
    super.key,
    required this.note,
    this.documentDirectory,
    this.onInsertImage,
    this.onInsertAudio,
  });

  @override
  State<ReaderNoteDialog> createState() => _ReaderNoteDialogState();
}

class _ReaderNoteDialogState extends State<ReaderNoteDialog> {
  final _editorKey = GlobalKey<_ReaderNoteEditorDialogState>();
  String? _drawingPath;

  @override
  void initState() {
    super.initState();
    for (final path in widget.note.attachments.reversed) {
      if (_isDrawingPath(path)) {
        _drawingPath = path;
        break;
      }
    }
  }

  bool _isDrawingPath(String path) =>
      path.toLowerCase().endsWith('.json') &&
      path.contains('${Platform.pathSeparator}note_drawings${Platform.pathSeparator}');

  Future<void> _editDrawing() async {
    NoteDrawingLayer? initial;
    final path = _drawingPath;
    if (path != null) {
      try {
        initial = await const NoteDrawingStorage().load(path);
      } catch (_) {
        initial = null;
      }
    }
    if (!mounted) return;
    final layer = await showDialog<NoteDrawingLayer>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        NoteDrawingLayer current = initial ?? const NoteDrawingLayer(strokes: []);
        return Dialog.fullscreen(
          child: Column(
            children: [
              AppBar(
                title: const Text('笔记手绘'),
                leading: IconButton(
                  tooltip: '取消',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(current),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: NoteDrawingEditor(
                  initialLayer: initial,
                  onChanged: (value) => current = value,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (layer == null || !mounted) return;
    if (layer.strokes.isEmpty) {
      setState(() => _drawingPath = null);
      return;
    }
    final saved = await const NoteDrawingStorage().save(widget.note.id, layer);
    if (mounted) setState(() => _drawingPath = saved);
  }

  ReaderAnnotation _buildAnnotation() {
    final base = _editorKey.currentState!.buildAnnotation();
    final attachments = base.attachments.where((path) => !_isDrawingPath(path)).toList();
    if (_drawingPath != null) attachments.add(_drawingPath!);
    return base.copyWith(attachments: List.unmodifiable(attachments));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 24).clamp(320.0, 900.0).toDouble();
    final height = (size.height - 48).clamp(320.0, 700.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: AppBar(
                automaticallyImplyLeading: false,
                title: const Text('笔记'),
                actions: [
                  IconButton(
                    tooltip: _drawingPath == null ? '添加手绘' : '编辑手绘',
                    onPressed: _editDrawing,
                    icon: Icon(_drawingPath == null ? Icons.draw_outlined : Icons.edit_note_outlined),
                  ),
                  if (_drawingPath != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Center(child: Icon(Icons.check_circle_outline, size: 18)),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_buildAnnotation()),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _ReaderNoteEditorDialogStateful(
                key: _editorKey,
                note: widget.note,
                documentDirectory: widget.documentDirectory,
                onInsertImage: widget.onInsertImage,
                onInsertAudio: widget.onInsertAudio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderNoteEditorDialogStateful extends StatefulWidget {
  final ReaderAnnotation note;
  final String? documentDirectory;
  final Future<String?> Function()? onInsertImage;
  final Future<String?> Function()? onInsertAudio;

  const _ReaderNoteEditorDialogStateful({
    super.key,
    required this.note,
    this.documentDirectory,
    this.onInsertImage,
    this.onInsertAudio,
  });

  @override
  State<_ReaderNoteEditorDialogStateful> createState() => _ReaderNoteEditorDialogState();
}

class _ReaderNoteEditorDialogState extends State<_ReaderNoteEditorDialogStateful> {
  final _editorKey = GlobalKey<ReaderNoteEditorState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ReaderNoteEditor(
        key: _editorKey,
        note: widget.note,
        documentDirectory: widget.documentDirectory,
        onInsertImage: widget.onInsertImage,
        onInsertAudio: widget.onInsertAudio,
      ),
    );
  }

  ReaderAnnotation buildAnnotation() => _editorKey.currentState!.buildAnnotation();
}
