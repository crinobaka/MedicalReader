import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/models/library_document.dart';
import '../../domain/models/reader_position.dart';
import '../../domain/models/reader_settings.dart';
import '../../services/reader_position_store.dart';
import '../../services/reader_settings_store.dart';
import '../controllers/epub_reader_controller.dart';
import '../widgets/epub_reader_settings_sheet.dart';
import '../widgets/epub_reader_view.dart';

class EpubReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;
  const EpubReaderPage({super.key, required this.document});

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  late final EpubReaderController _controller;
  ReaderSettings _settings = const ReaderSettings();
  bool _settingsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _controller = EpubReaderController(
      document: widget.document,
      initialPosition: ref.read(readerPositionStoreProvider).read(widget.document),
      onPositionSaved: _savePosition,
    )..open().then((_) {
        if (mounted) setState(() {});
      });
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(readerSettingsStoreProvider).load(widget.document);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _settingsLoading = false;
    });
  }

  Future<void> _saveSettings(ReaderSettings settings) async {
    setState(() => _settings = settings);
    await ref.read(readerSettingsStoreProvider).save(widget.document, settings);
  }

  Future<void> _savePosition(ReaderPosition position) {
    return ref.read(readerPositionStoreProvider).save(widget.document, position);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EpubReaderSettingsSheet(
        settings: _settings,
        onChanged: _saveSettings,
      ),
    );
  }

  Future<void> _handleBoundary(String direction) async {
    await _controller.navigatePageBoundary(direction);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading || _settingsLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
          IconButton(tooltip: '阅读设置', onPressed: _openSettings, icon: const Icon(Icons.text_fields)),
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
        key: ValueKey('${_controller.chapterIndex}:${_controller.initialProgress}:${_controller.initialFragment}:${_settings.toJson()}'),
        archive: _controller.archive!,
        chapterIndex: _controller.chapterIndex,
        fragment: _controller.initialFragment,
        initialProgress: _controller.initialProgress,
        settings: _settings,
        onPositionChanged: (href, progress) => _controller.updateProgress(href, progress),
        onPageBoundary: _handleBoundary,
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
