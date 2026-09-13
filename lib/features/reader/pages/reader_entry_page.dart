import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../library/models/library_document.dart';
import '../epub/pages/epub_reader_page.dart';
import 'reader_page.dart';

/// Unified reader entry point. The library only needs to know about a
/// LibraryDocument; format-specific runtime selection stays inside Reader.
class ReaderEntryPage extends StatefulWidget {
  final LibraryDocument document;
  final int initialPage;

  const ReaderEntryPage({
    super.key,
    required this.document,
    this.initialPage = 0,
  });

  @override
  State<ReaderEntryPage> createState() => _ReaderEntryPageState();
}

class _ReaderEntryPageState extends State<ReaderEntryPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setReaderWakeLock(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setReaderWakeLock(state == AppLifecycleState.resumed);
  }

  Future<void> _setReaderWakeLock(bool enabled) async {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.document.format) {
      case LibraryDocumentFormat.pdf:
        return ReaderPage(document: widget.document, initialPage: widget.initialPage);
      case LibraryDocumentFormat.epub:
        return EpubReaderPage(document: widget.document);
      case LibraryDocumentFormat.other:
        return Scaffold(
          appBar: AppBar(title: const Text('阅读器')),
          body: Center(
            child: Text('暂不支持此文件格式：${widget.document.file.name}'),
          ),
        );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setReaderWakeLock(false);
    super.dispose();
  }
}
