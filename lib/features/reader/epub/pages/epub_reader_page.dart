import 'package:flutter/material.dart';

import '../../../library/models/library_document.dart';
import '../controllers/epub_reader_controller.dart';
import '../widgets/epub_reader_view.dart';

class EpubReaderPage extends StatefulWidget {
  final LibraryDocument document;
  const EpubReaderPage({super.key, required this.document});

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late final EpubReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController(document: widget.document)..open().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_controller.error != null || _controller.archive == null) {
      return Scaffold(appBar: AppBar(title: const Text('EPUB')), body: Center(child: Text('${_controller.error ?? 'Unable to open EPUB'}')));
    }
    final book = _controller.book!;
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (book.spine.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Chapters',
              onSelected: (index) => setState(() => _controller.goToChapter(index)),
              itemBuilder: (_) => [
                for (var i = 0; i < book.spine.length; i++)
                  PopupMenuItem(value: i, child: Text(_chapterTitle(i))),
              ],
            ),
        ],
      ),
      body: EpubReaderView(
        key: ValueKey(_controller.chapterIndex),
        archive: _controller.archive!,
        chapterIndex: _controller.chapterIndex,
        onPositionChanged: (href, progress) => _controller.updateProgress(href, progress),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '阅读'),
        ],
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(onPressed: _controller.chapterIndex > 0 ? () => setState(() => _controller.previousChapter()) : null, icon: const Icon(Icons.chevron_left)),
          const SizedBox(width: 8),
          IconButton.filledTonal(onPressed: _controller.chapterIndex + 1 < _controller.chapterCount ? () => setState(() => _controller.nextChapter()) : null, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  String _chapterTitle(int index) {
    final item = _controller.archive!.book.manifestById(_controller.archive!.book.spine[index].idref);
    return item?.href.split('/').last ?? 'Chapter ${index + 1}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
