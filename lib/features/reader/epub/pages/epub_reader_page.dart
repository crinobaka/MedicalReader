import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/models/library_document.dart';
import '../../../library/providers/library_repository_provider.dart';
import '../../domain/models/reader_locator.dart';
import '../../domain/models/reader_position.dart';
import '../controllers/epub_reader_controller.dart';
import '../widgets/epub_reader_view.dart';

class EpubReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;
  const EpubReaderPage({super.key, required this.document});

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  late final EpubReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController(
      document: widget.document,
      initialPosition: _initialPosition,
      onPositionSaved: _savePosition,
    )..open().then((_) {
        if (mounted) setState(() {});
      });
  }

  ReaderPosition? get _initialPosition {
    final raw = widget.document.metadata['reader_position'];
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      final locator = ReaderLocator.fromJson(json['locator'] is Map ? Map<String, dynamic>.from(json['locator']) : json);
      final progress = (json['progress'] as num?)?.toDouble() ?? 0;
      return ReaderPosition(locator: locator, progress: progress.clamp(0, 1).toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePosition(ReaderPosition position) async {
    await ref.read(libraryRepositoryProvider).updateDocumentMetadata(
      documentId: widget.document.id,
      metadata: {
        'reader_position': position.toJson(),
        'last_read_at': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_controller.error != null || _controller.archive == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('EPUB')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${_controller.error ?? 'Unable to open EPUB'}'))),
      );
    }

    final book = _controller.book!;
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (book.spine.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: '章节',
              onSelected: (index) async {
                await _controller.goToChapter(index);
                if (mounted) setState(() {});
              },
              itemBuilder: (_) => [
                for (var i = 0; i < book.spine.length; i++)
                  PopupMenuItem(value: i, child: Text(_chapterTitle(i))),
              ],
            ),
        ],
      ),
      body: EpubReaderView(
        key: ValueKey('${_controller.chapterIndex}:${_controller.initialProgress}'),
        archive: _controller.archive!,
        chapterIndex: _controller.chapterIndex,
        initialProgress: _controller.initialProgress,
        onPositionChanged: (href, progress) => _controller.updateProgress(href, progress),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            onPressed: _controller.chapterIndex > 0
                ? () async {
                    await _controller.previousChapter();
                    if (mounted) setState(() {});
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _controller.chapterIndex + 1 < _controller.chapterCount
                ? () async {
                    await _controller.nextChapter();
                    if (mounted) setState(() {});
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
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
