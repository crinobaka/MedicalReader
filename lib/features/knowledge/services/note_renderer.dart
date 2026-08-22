import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../reader/models/reader_annotation.dart';
import '../models/note_document.dart';

class NoteRenderer {
  const NoteRenderer();

  Widget build(BuildContext context, NoteDocument note) {
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
        return Html(data: note.body);
    }
  }
}
