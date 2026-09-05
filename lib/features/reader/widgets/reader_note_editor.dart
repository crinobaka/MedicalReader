import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/reader_annotation.dart';
import '../services/reader_note_service.dart';
import 'reader_note_attachments.dart';

class _ReaderNoteTextEditingController extends TextEditingController {
  _ReaderNoteTextEditingController({super.text});

  static final _inlineSyntax = RegExp(
    r'(\\`[^\\`]*\\`|\\*\\*[^\\*]+\\*\\*|__[^_]+__|\\*[^\\*]+\\*|_[^_]+_|~~[^~]+~~|\\[[^\\]]+\\]\\([^\\)]+\\)|<[^>]+>)',
  );
  static final _heading = RegExp(r'^(#{1,6})(\\s+)(.*)\$');
  static final _quoteOrList = RegExp(r'^(\\s*(?:>|[-*+] |\\d+\\. ))');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final markdown = Theme.of(context).brightness == Brightness.dark;
    final syntax = markdown ? const Color(0xFF9CDCFE) : const Color(0xFF795E26);
    final heading = markdown ? const Color(0xFF4EC9B0) : const Color(0xFF0451A5);
    final emphasis = markdown ? const Color(0xFFDCDCAA) : const Color(0xFF800000);
    final code = markdown ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final link = markdown ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final quote = markdown ? const Color(0xFF6A9955) : const Color(0xFF008000);

    final spans = <InlineSpan>[];
    final lines = text.split('\\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final headingMatch = _heading.firstMatch(line);
      if (headingMatch != null) {
        spans.add(TextSpan(
          text: '${headingMatch.group(1)}${headingMatch.group(2)}',
          style: base.copyWith(color: syntax, fontWeight: FontWeight.w600),
        ));
        spans.add(TextSpan(
          text: headingMatch.group(3),
          style: base.copyWith(color: heading, fontWeight: FontWeight.w700),
        ));
      } else {
        final prefixMatch = _quoteOrList.firstMatch(line);
        final prefixEnd = prefixMatch?.end ?? 0;
        if (prefixMatch != null) {
          spans.add(TextSpan(
            text: line.substring(0, prefixEnd),
            style: base.copyWith(color: quote, fontWeight: FontWeight.w600),
          ));
        }
        spans.addAll(_inlineSpans(
          line.substring(prefixEnd),
          base,
          syntax,
          emphasis,
          code,
          link,
        ));
      }
      if (lineIndex < lines.length - 1) spans.add(const TextSpan(text: '\\n'));
    }

    return TextSpan(style: base, children: spans);
  }

  List<InlineSpan> _inlineSpans(
    String value,
    TextStyle base,
    Color syntax,
    Color emphasis,
    Color code,
    Color link,
  ) {
    final result = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineSyntax.allMatches(value)) {
      if (match.start > cursor) result.add(TextSpan(text: value.substring(cursor, match.start)));
      final token = match.group(0)!;
      Color tokenColor = syntax;
      FontWeight? weight;
      FontStyle? fontStyle;
      if (token.startsWith('**') || token.startsWith('__')) {
        tokenColor = emphasis;
        weight = FontWeight.w700;
      } else if (token.startsWith('*') || token.startsWith('_')) {
        tokenColor = emphasis;
        fontStyle = FontStyle.italic;
      } else if (token.startsWith('~~')) {
        tokenColor = emphasis;
        weight = FontWeight.w600;
      } else if (token.startsWith('`')) {
        tokenColor = code;
        fontFamily = 'monospace';
      } else if (token.startsWith('[')) {
        tokenColor = link;
        weight = FontWeight.w500;
      } else if (token.startsWith('<')) {
        tokenColor = syntax;
      }
      result.add(TextSpan(
        text: token,
        style: base.copyWith(color: tokenColor, fontWeight: weight, fontStyle: fontStyle, fontFamily: fontFamily),
      ));
      cursor = match.end;
    }
    if (cursor < value.length) result.add(TextSpan(text: value.substring(cursor)));
    return result;
  }
}

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
  late final _ReaderNoteTextEditingController _contentController;
  ReaderNoteFormat _format = ReaderNoteFormat.markdown;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = _ReaderNoteTextEditingController(text: widget.note.content);
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
    final imagePattern = RegExp(r'!\\[([^\\]]*)\\]\\(([^)]+)\\)');
    return content.replaceAllMapped(imagePattern, (match) {
      final alt = match.group(1) ?? '图片';
      final path = _resolvePath(match.group(2) ?? '');
      return '![$alt](${Uri.file(path)})';
    });
  }

  String _resolveHtml(String content) {
    final srcPattern = RegExp(r'''((?:src|href)=["\\'])([^"\\']+)(["\\'])''', caseSensitive: false);
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
              : TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: InputDecoration(
                    hintText: _format == ReaderNoteFormat.markdown ? '在这里输入 Markdown 笔记……' : '在这里输入 HTML 笔记……',
                    border: const OutlineInputBorder(),
                  ),
                ),
        ),
      ],
    );
  }

  ReaderAnnotation buildAnnotation() => widget.note.copyWith(title: _titleController.text.trim(), content: _contentController.text, noteFormat: _format, updatedAt: DateTime.now());
}
