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
        return MarkdownBody(
          data: note.body,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(),
            textAlign: WrapAlignment.start,
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            codeblockDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            codeblockPadding: const EdgeInsets.all(14),
          ),
        );
      case ReaderNoteFormat.markdownHtml:
        return Html(data: note.body);
    }
  }
}
