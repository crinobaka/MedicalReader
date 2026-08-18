import 'package:flutter/material.dart';

import '../models/reader_annotation.dart';
import 'reader_note_editor.dart';

class ReaderNoteDialog extends StatefulWidget {
  final ReaderAnnotation note;

  final Future<String?> Function()? onInsertImage;

  final Future<String?> Function()? onInsertAudio;

  const ReaderNoteDialog({
    super.key,
    required this.note,
    this.onInsertImage,
    this.onInsertAudio,
  });

  @override
  State<ReaderNoteDialog> createState() =>
      _ReaderNoteDialogState();
}

class _ReaderNoteDialogState
    extends State<ReaderNoteDialog> {
  final _editorKey =
      GlobalKey<_ReaderNoteEditorDialogState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 700,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('笔记'),
              actions: [
                TextButton(
                  onPressed: () {
                    final note =
                        _editorKey.currentState
                            ?.buildAnnotation();

                    Navigator.of(context).pop(note);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
            Expanded(
              child: _ReaderNoteEditorDialogStateful(
                key: _editorKey,
                note: widget.note,
                onInsertImage:
                    widget.onInsertImage,
                onInsertAudio:
                    widget.onInsertAudio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderNoteEditorDialogStateful
    extends StatefulWidget {
  final ReaderAnnotation note;

  final Future<String?> Function()? onInsertImage;

  final Future<String?> Function()? onInsertAudio;

  const _ReaderNoteEditorDialogStateful({
    super.key,
    required this.note,
    this.onInsertImage,
    this.onInsertAudio,
  });

  @override
  State<_ReaderNoteEditorDialogStateful> createState() =>
      _ReaderNoteEditorDialogState();
}

class _ReaderNoteEditorDialogState
    extends State<_ReaderNoteEditorDialogStateful> {
  final _editorKey =
      GlobalKey<ReaderNoteEditorState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ReaderNoteEditor(
        key: _editorKey,
        note: widget.note,
        onInsertImage: widget.onInsertImage,
        onInsertAudio: widget.onInsertAudio,
      ),
    );
  }

  ReaderAnnotation buildAnnotation() {
    return _editorKey.currentState!.buildAnnotation();
  }
}