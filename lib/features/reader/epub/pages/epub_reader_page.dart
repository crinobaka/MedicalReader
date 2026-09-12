import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/reader_position.dart';
import '../../domain/models/reader_settings.dart';
import '../../models/reader_annotation.dart';
import '../../models/reader_mining.dart';
import '../../providers/reader_annotation_provider.dart';
import '../../providers/reader_position_provider.dart';
import '../../services/reader_anki_service.dart';
import '../../services/reader_dictionary_service.dart';
import '../../widgets/reader_lookup_sheet.dart';
import '../../widgets/reader_mining_sheet.dart';
import '../controllers/epub_reader_controller.dart';
import '../models/epub_book.dart';
import '../widgets/epub_reader_settings_sheet.dart';
import '../widgets/epub_reader_view.dart';

class EpubReaderPage extends ConsumerStatefulWidget {
  const EpubReaderPage({super.key, required this.document});
  final dynamic document;

  @override
  ConsumerState<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends ConsumerState<EpubReaderPage> {
  late final EpubReaderController _controller;
  ReaderSettings _settings = const ReaderSettings();
  final ReaderDictionaryRegistry _dictionary = const ReaderDictionaryRegistry();
  final ReaderAnkiService _anki = const DisabledReaderAnkiService();

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController(
      document: widget.document,
      initialPosition: ref.read(readerPositionStoreProvider).read(widget.document),
      onPositionSaved: _savePosition,
    )..open();
  }

  Future<void> _savePosition(ReaderPosition position) async {
    await ref.read(readerPositionStoreProvider).save(widget.document, position);
  }

  List<EpubNavItem> get _navigation {
    final book = _controller.book;
    if (book == null) return const [];
    final result = <EpubNavItem>[];
    void visit(List<EpubNavItem> items, int depth) {
      for (final item in items) {
        result.add(EpubNavItem(
          title: '${List.filled(depth, '  ').join()}${item.title}',
          href: item.href,
          children: item.children,
        ));
        visit(item.children, depth + 1);
      }
    }
    visit(book.navigation, 0);
    return result;
  }

  List<ReaderAnnotation> get _annotations => ref.read(readerAnnotationsProvider(widget.document));

  String _chapterTitle(int index) {
    final book = _controller.book;
    if (book == null || book.spine.isEmpty) return 'EPUB';
    final chapter = book.spine[index.clamp(0, book.spine.length - 1)];
    return chapter.title?.isNotEmpty == true ? chapter.title! : chapter.href.split('/').last;
  }

  Future<void> _toggleBookmark() async {
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations
        .where((x) => x.type == ReaderAnnotationType.bookmark && x.pageIndex == _controller.chapterIndex)
        .toList(growable: false);
    if (existing.isNotEmpty) {
      for (final item in existing) {
        await notifier.remove(item.id);
      }
      if (mounted) setState(() {});
      return;
    }
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(
      id: 'epub_bookmark_${widget.document.id}_${_controller.chapterIndex}',
      bookId: widget.document.id,
      pageIndex: _controller.chapterIndex,
      type: ReaderAnnotationType.bookmark,
      title: _chapterTitle(_controller.chapterIndex),
      createdAt: now,
      updatedAt: now,
    ));
    if (mounted) setState(() {});
  }

  Future<void> _saveNote() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('笔记 · ${_chapterTitle(_controller.chapterIndex)}'),
        content: TextField(controller: controller, maxLines: 6, autofocus: true, decoration: const InputDecoration(hintText: '输入阅读笔记…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final now = DateTime.now();
    await ref.read(readerAnnotationsProvider(widget.document).notifier).add(ReaderAnnotation(
      id: 'epub_note_${widget.document.id}_${_controller.chapterIndex}_${now.microsecondsSinceEpoch}',
      bookId: widget.document.id,
      pageIndex: _controller.chapterIndex,
      type: ReaderAnnotationType.note,
      title: _chapterTitle(_controller.chapterIndex),
      content: value,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _openAnnotations() async {
    final items = _annotations;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, index) {
            final item = items[index];
            return ListTile(
              leading: Icon(item.type == ReaderAnnotationType.note ? Icons.note_outlined : Icons.bookmark_outline),
              title: Text(item.title?.isNotEmpty == true ? item.title! : _chapterTitle(item.pageIndex)),
              subtitle: Text(item.content?.isNotEmpty == true ? item.content! : '第 ${item.pageIndex + 1} 章'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_controller.goToChapter(item.pageIndex));
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openLookup() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ReaderLookupSheet(),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final request = DictionaryLookupRequest(text: selected);
    final entries = await _dictionary.lookup(request);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReaderMiningSheet(
        selectedText: selected,
        entries: entries,
        anki: _anki,
      ),
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpubReaderSettingsSheet(
        settings: _settings,
        navigation: _navigation,
        currentChapter: _controller.chapterIndex,
        onChanged: (value) => setState(() => _settings = value),
        onNavigationSelected: (item) => _controller.goToNavigation(item),
        onBookmark: _toggleBookmark,
        onNote: _saveNote,
        onAnnotations: _openAnnotations,
        onSearch: _openLookup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_controller.error != null) {
      return Scaffold(body: Center(child: Text('EPUB 打开失败：${_controller.error}')));
    }
    return Scaffold(
      body: EpubReaderView(
        document: widget.document,
        controller: _controller,
        settings: _settings,
        onSettings: _openSettings,
        onPositionChanged: (position) => _controller.updateProgress(position.progress),
        onPageBoundary: _controller.navigatePageBoundary,
        onSelectionChanged: (text) {
          if (text == null || text.isEmpty) return;
          _openLookup();
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
