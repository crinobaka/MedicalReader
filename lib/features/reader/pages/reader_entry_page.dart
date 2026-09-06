import 'package:flutter/material.dart';

import '../../library/models/library_document.dart';
import '../epub/pages/epub_reader_page.dart';
import 'reader_page.dart';

/// Unified reader entry point. The library only needs to know about a
/// LibraryDocument; format-specific runtime selection stays inside Reader.
class ReaderEntryPage extends StatelessWidget {
  final LibraryDocument document;
  final int initialPage;

  const ReaderEntryPage({
    super.key,
    required this.document,
    this.initialPage = 0,
  });

  @override
  Widget build(BuildContext context) {
    switch (document.format) {
      case LibraryDocumentFormat.pdf:
        return ReaderPage(document: document, initialPage: initialPage);
      case LibraryDocumentFormat.epub:
        return EpubReaderPage(document: document);
      case LibraryDocumentFormat.other:
        return Scaffold(
          appBar: AppBar(title: const Text('阅读器')),
          body: Center(
            child: Text('暂不支持此文件格式：${document.file.name}'),
          ),
        );
    }
  }
}
