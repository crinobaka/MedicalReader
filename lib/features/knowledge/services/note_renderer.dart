import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../reader/models/reader_annotation.dart';
import '../models/note_document.dart';

/// Note 渲染入口。
///
/// Renderer 首先判断 Note 格式，再选择唯一对应的解析器：
/// Markdown -> Markdown renderer
/// Markdown-HTML -> HTML renderer
///
/// Markdown-HTML 不会再次经过 Markdown parser。
class NoteRenderer {
  const NoteRenderer();

  Widget build(NoteDocument note) {
    switch (note.format) {
      case ReaderNoteFormat.markdown:
        return Markdown(
          data: note.body,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(_context)).copyWith(
            p: const TextStyle(textAlign: TextAlign.left),
          ),
        );
      case ReaderNoteFormat.markdownHtml:
        return _HtmlNoteView(html: note.body);
    }
  }

  // The renderer is normally used through buildInContext below. Kept private
  // so callers do not need to know about the implementation details.
  BuildContext get _context => throw StateError('Use buildInContext');

  Widget buildInContext(BuildContext context, NoteDocument note) {
    switch (note.format) {
      case ReaderNoteFormat.markdown:
        return Markdown(
          data: note.body,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(textAlign: TextAlign.left),
          ),
        );
      case ReaderNoteFormat.markdownHtml:
        return _HtmlNoteView(html: note.body);
    }
  }
}

/// Dedicated HTML renderer boundary.
///
/// This intentionally does not invoke Markdown. A real HTML widget can replace
/// this implementation without changing Note storage or the renderer API.
class _HtmlNoteView extends StatelessWidget {
  final String html;

  const _HtmlNoteView({required this.html});

  @override
  Widget build(BuildContext context) {
    return SelectableText(html);
  }
}
