import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../reader/models/reader_annotation.dart';
import '../models/note_document.dart';

/// Note 渲染入口。
///
/// Renderer 首先判断 Note 格式，再选择唯一对应的解析器：
/// Markdown -> Markdown renderer
/// Markdown-HTML -> HTML renderer
///
/// 因此 Markdown-HTML 不会再次经过 Markdown parser。
class NoteRenderer {
  const NoteRenderer();

  Widget build(NoteDocument note) {
    switch (note.format) {
      case ReaderNoteFormat.markdown:
        return Markdown(
          data: note.body,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(
            const DefaultTextStyle.fallback().style is TextStyle
                ? ThemeData.fallback()
                : ThemeData.fallback(),
          ).copyWith(
            p: const TextStyle(textBaseline: TextBaseline.alphabetic),
          ),
        );
      case ReaderNoteFormat.markdownHtml:
        return _HtmlNoteView(html: note.body);
    }
  }
}

/// Minimal HTML renderer boundary.
///
/// HTML support is deliberately kept behind this widget so the storage model
/// does not depend on a particular HTML package. The current fallback renders
/// plain text rather than parsing HTML as Markdown, preserving the important
/// format separation until a dedicated HTML renderer is introduced.
class _HtmlNoteView extends StatelessWidget {
  final String html;

  const _HtmlNoteView({required this.html});

  @override
  Widget build(BuildContext context) {
    return SelectableText(html);
  }
}
