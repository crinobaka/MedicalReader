import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/reader_annotation.dart';
import '../services/reader_note_service.dart';
import 'reader_note_attachments.dart';

class ReaderNoteEditor extends StatefulWidget {
  final ReaderAnnotation note;
  final String? documentDirectory;
  final Future<String?> Function()? onInsertImage;
  final Future<String?> Function()? onInsertAudio;

  const ReaderNoteEditor({super.key, required this.note, this.documentDirectory, this.onInsertImage, this.onInsertAudio});

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
      _contentController.selection = TextSelection.collapsed(offset: content.length);
    });
  }

  void _appendAudio(String path) {
    final content = _noteService.appendAudio(_contentController.text, path);
    setState(() {
      _contentController.text = content;
      _contentController.selection = TextSelection.collapsed(offset: content.length);
    });
  }

  String _resolvePath(String value) {
    final directory = widget.documentDirectory;
    if (directory == null || directory.isEmpty) return value;
    return _noteService.resolveAttachmentPath(value, directory);
  }

  String _resolveMarkdown(String content) {
    final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    return content.replaceAllMapped(imagePattern, (match) {
      final alt = match.group(1) ?? '图片';
      final path = _resolvePath(match.group(2) ?? '');
      return '![$alt](${Uri.file(path)})';
    });
  }

  String _resolveHtml(String content) {
    final srcPattern = RegExp(r'''((?:src|href)=["\'])([^"\']+)(["\'])''', caseSensitive: false);
    return content.replaceAllMapped(srcPattern, (match) {
      final path = _resolvePath(match.group(2) ?? '');
      if (path == match.group(2)) return match.group(0)!;
      return '${match.group(1)}${Uri.file(path)}${match.group(3)}';
    });
  }

  Widget _missingImage(String? alt, String path) {
    return ListTile(
      leading: const Icon(Icons.broken_image_outlined),
      title: Text(alt?.isNotEmpty == true ? alt! : '图片无法读取'),
      subtitle: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildMarkdownPreview() {
    return MarkdownBody(
      data: _resolveMarkdown(_contentController.text),
      selectable: true,
      imageBuilder: (uri, title, alt) {
        final path = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
        if (path.startsWith('http://') || path.startsWith('https://')) {
          return Image.network(path, fit: BoxFit.contain);
        }
        final file = File(path);
        return file.existsSync()
            ? Image.file(file, fit: BoxFit.contain, errorBuilder: (_, _, _) => _missingImage(alt, path))
            : _missingImage(alt, path);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _titleController, maxLines: 1, decoration: const InputDecoration(labelText: '笔记标题', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SegmentedButton<ReaderNoteFormat>(
                segments: const [
                  ButtonSegment(value: ReaderNoteFormat.markdown, label: Text('Markdown')),
                  ButtonSegment(value: ReaderNoteFormat.markdownHtml, label: Text('Markdown-HTML')),
                ],
                selected: {_format},
                onSelectionChanged: (values) => setState(() => _format = values.first),
              ),
              IconButton(tooltip: '插入图片', onPressed: widget.onInsertImage == null ? null : () async { final path = await widget.onInsertImage!(); if (path != null && path.isNotEmpty) _appendImage(path); }, icon: const Icon(Icons.photo_camera)),
              IconButton(tooltip: '插入录音', onPressed: widget.onInsertAudio == null ? null : () async { final path = await widget.onInsertAudio!(); if (path != null && path.isNotEmpty) _appendAudio(path); }, icon: const Icon(Icons.mic)),
              IconButton(tooltip: _preview ? '编辑' : '预览', onPressed: () => setState(() => _preview = !_preview), icon: Icon(_preview ? Icons.edit : Icons.preview)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _preview
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_format == ReaderNoteFormat.markdown) _buildMarkdownPreview() else Html(data: _resolveHtml(_contentController.text)),
                      ReaderNoteAttachments(content: _contentController.text),
                    ],
                  ),
                )
              : TextField(controller: _contentController, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: InputDecoration(hintText: _format == ReaderNoteFormat.markdown ? '在这里输入 Markdown 笔记……' : '在这里输入 HTML 笔记……', border: const OutlineInputBorder())),
        ),
      ],
    );
  }

  ReaderAnnotation buildAnnotation() => widget.note.copyWith(title: _titleController.text.trim(), content: _contentController.text, noteFormat: _format, updatedAt: DateTime.now());
}
