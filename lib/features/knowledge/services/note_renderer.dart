import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../reader/models/reader_annotation.dart';
import '../models/note_document.dart';

/// Note 渲染入口。
///
/// Markdown 与 Markdown-HTML 使用完全不同的 renderer。
/// Markdown-HTML 永远不会再次经过 Markdown parser。
class NoteRenderer {
  const NoteRenderer();

  Widget build(BuildContext context, NoteDocument note) {
    switch (note.format) {
      case ReaderNoteFormat.markdown:
        return Markdown(
          data: note.body,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(
            Theme.of(context),
          ).copyWith(
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
/// 当前项目尚未引入 HTML widget 依赖，因此先保留独立边界。
/// 后续接入 HTML renderer 时只替换这里，不修改 Note 数据模型。
class _HtmlNoteView extends StatelessWidget {
  final String html;

  const _HtmlNoteView({required this.html});

  @override
  Widget build(BuildContext context) {
    return SelectableText(html);
  }
}
