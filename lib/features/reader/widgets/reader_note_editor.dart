import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/reader_annotation.dart';
import '../services/reader_note_service.dart';

class ReaderNoteEditor extends StatefulWidget {
  final ReaderAnnotation note;

  final Future<String?> Function()? onInsertImage;

  final Future<String?> Function()? onInsertAudio;

  const ReaderNoteEditor({
    super.key,
    required this.note,
    this.onInsertImage,
    this.onInsertAudio,
  });

  @override
  ReaderNoteEditorState createState() => ReaderNoteEditorState();
}

class ReaderNoteEditorState extends State<ReaderNoteEditor> {
  final ReaderNoteService _noteService = const ReaderNoteService();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  ReaderNoteFormat _format = ReaderNoteFormat.markdown;

  bool _preview = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.note.title);

    _contentController = TextEditingController(text: widget.note.content);

    _format = widget.note.noteFormat;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _appendImage(String path) {
    final content = _noteService.appendImage(_contentController.text, path);

    setState(() {
      _contentController.text = content;
      _contentController.selection = TextSelection.collapsed(
        offset: content.length,
      );
    });
  }

  void _appendAudio(String path) {
    final content = _noteService.appendAudio(_contentController.text, path);

    setState(() {
      _contentController.text = content;
      _contentController.selection = TextSelection.collapsed(
        offset: content.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '笔记标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            SegmentedButton<ReaderNoteFormat>(
              segments: const [
                ButtonSegment(
                  value: ReaderNoteFormat.markdown,
                  label: Text('Markdown'),
                ),
                ButtonSegment(
                  value: ReaderNoteFormat.markdownHtml,
                  label: Text('Markdown + HTML'),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (values) {
                setState(() {
                  _format = values.first;
                });
              },
            ),
            const Spacer(),
            IconButton(
              tooltip: '插入图片',
              onPressed: widget.onInsertImage == null
                  ? null
                  : () async {
                      final path = await widget.onInsertImage!();

                      if (path != null && path.isNotEmpty) {
                        _appendImage(path);
                      }
                    },
              icon: const Icon(Icons.photo_camera),
            ),
            IconButton(
              tooltip: '插入录音',
              onPressed: widget.onInsertAudio == null
                  ? null
                  : () async {
                      final path = await widget.onInsertAudio!();

                      if (path != null && path.isNotEmpty) {
                        _appendAudio(path);
                      }
                    },
              icon: const Icon(Icons.mic),
            ),
            IconButton(
              tooltip: _preview ? '编辑' : '预览',
              onPressed: () {
                setState(() {
                  _preview = !_preview;
                });
              },
              icon: Icon(_preview ? Icons.edit : Icons.preview),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Expanded(
          child: _preview
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: MarkdownBody(
                    data: _contentController.text,
                    selectable: true,
                  ),
                )
              : TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '在这里输入 Markdown 笔记……',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_preview) {
                      setState(() {});
                    }
                  },
                ),
        ),
      ],
    );
  }

  ReaderAnnotation buildAnnotation() {
    final now = DateTime.now();

    return widget.note.copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text,
      noteFormat: _format,
      updatedAt: now,
    );
  }
}
