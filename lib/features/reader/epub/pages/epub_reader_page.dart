import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/models/library_document.dart';
import '../../domain/models/reader_lookup.dart';
import '../../domain/models/reader_mining.dart';
import '../../domain/models/reader_position.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/services/reader_anki_service.dart';
import '../../domain/services/reader_dictionary_service.dart';
import '../../models/reader_annotation.dart';
import '../../providers/reader_annotation_provider.dart';
import '../../services/reader_position_store.dart';
import '../../services/reader_settings_store.dart';
import '../../widgets/reader_lookup_sheet.dart';
import '../../widgets/reader_mining_sheet.dart';
import '../controllers/epub_reader_controller.dart';
import '../models/epub_book.dart';
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
  final ReaderDictionaryRegistry _dictionary = const ReaderDictionaryRegistry();
  final ReaderAnkiService _anki = const DisabledReaderAnkiService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _controller = EpubReaderController(
      document: widget.document,
      initialPosition: ref.read(readerPositionStoreProvider).read(widget.document),
      onPositionSaved: _savePosition,
    )..open().then((_) { if (mounted) setState(() {}); });
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(readerSettingsStoreProvider).load(widget.document);
    if (!mounted) return;
    setState(() { _settings = settings; _settingsLoading = false; });
  }

  Future<void> _saveSettings(ReaderSettings settings) async {
    setState(() => _settings = settings);
    await ref.read(readerSettingsStoreProvider).save(widget.document, settings);
  }

  Future<void> _savePosition(ReaderPosition position) => ref.read(readerPositionStoreProvider).save(widget.document, position);
  List<ReaderAnnotation> get _annotations => ref.watch(readerAnnotationsProvider(widget.document));
  bool get _bookmarked => _annotations.any((x) => x.type == ReaderAnnotationType.bookmark && x.pageIndex == _controller.chapterIndex);

  List<EpubNavItem> get _navigation {
    final result = <EpubNavItem>[];
    void visit(List<EpubNavItem> items, int depth) {
      for (final item in items) {
        result.add(EpubNavItem(title: '${'  ' * depth}${item.title}', href: item.href, fragment: item.fragment, children: item.children));
        visit(item.children, depth + 1);
      }
    }
    visit(_controller.book?.navigation ?? const [], 0);
    return result;
  }

  void _openSettings() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => EpubReaderSettingsSheet(
          settings: _settings,
          onChanged: _saveSettings,
          navigation: _navigation,
          currentChapter: _controller.chapterIndex,
          onNavigationSelected: (item) async {
            Navigator.of(context).pop();
            await _controller.goToNavigation(item);
            if (mounted) setState(() {});
          },
          onBookmark: _toggleBookmark,
          onNote: _saveNote,
          onAnnotations: _openAnnotations,
        ),
      );

  Future<void> _toggleBookmark() async {
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((x) => x.type == ReaderAnnotationType.bookmark && x.pageIndex == _controller.chapterIndex).toList(growable: false);
    if (existing.isNotEmpty) {
      for (final item in existing) await notifier.remove(item.id);
      if (mounted) setState(() {});
      return;
    }
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(id: 'epub_bookmark_${widget.document.id}_${_controller.chapterIndex}', bookId: widget.document.id, pageIndex: _controller.chapterIndex, type: ReaderAnnotationType.bookmark, title: _chapterTitle(_controller.chapterIndex), createdAt: now, updatedAt: now));
    if (mounted) setState(() {});
  }

  Future<void> _saveNote() async {
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((x) => x.type == ReaderAnnotationType.note && x.pageIndex == _controller.chapterIndex).firstOrNull;
    final editor = TextEditingController(text: existing?.content ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '添加笔记' : '编辑笔记'),
        content: TextField(controller: editor, autofocus: true, minLines: 4, maxLines: 10, decoration: const InputDecoration(hintText: '写下这一章的阅读笔记…')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, editor.text.trim()), child: const Text('保存'))],
      ),
    );
    editor.dispose();
    if (text == null || text.isEmpty) return;
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(id: existing?.id ?? 'epub_note_${widget.document.id}_${_controller.chapterIndex}', bookId: widget.document.id, pageIndex: _controller.chapterIndex, type: ReaderAnnotationType.note, title: _chapterTitle(_controller.chapterIndex), content: text, createdAt: existing?.createdAt ?? now, updatedAt: now));
  }

  void _openAnnotations() {
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text('标注与笔记', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_annotations.isEmpty) const ListTile(title: Text('还没有保存的标注')),
            for (final item in _annotations)
              ListTile(
                leading: Icon(_iconForAnnotation(item.type)),
                title: Text(item.title.isNotEmpty ? item.title : _chapterTitle(item.pageIndex)),
                subtitle: Text(item.content.isNotEmpty ? item.content : item.type.name),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _controller.goToChapter(item.pageIndex.clamp(0, _controller.chapterCount - 1));
                  if (mounted) setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForAnnotation(ReaderAnnotationType type) => switch (type) {
        ReaderAnnotationType.bookmark => Icons.bookmark_rounded,
        ReaderAnnotationType.note => Icons.sticky_note_2_rounded,
        ReaderAnnotationType.highlight => Icons.highlight_rounded,
        ReaderAnnotationType.tag => Icons.sell_outlined,
        ReaderAnnotationType.ink => Icons.draw_rounded,
      };

  Future<void> _openLookup(ReaderLookupContext lookup) async {
    final entry = await showModalBottomSheet<DictionaryEntry>(context: context, isScrollControlled: true, builder: (_) => ReaderLookupSheet(contextData: lookup, dictionary: _dictionary));
    if (entry == null || !mounted) return;
    final mined = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => ReaderMiningSheet(entry: entry, onMine: _mineToAnki));
    if (mined == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提交 Anki 卡片')));
  }

  Future<bool> _mineToAnki(AnkiCardDraft draft) => _anki.createCard(draft);
  Future<void> _handleBoundary(String direction) async { await _controller.navigatePageBoundary(direction); if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (_controller.loading || _settingsLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_controller.error != null || _controller.archive == null) return Scaffold(appBar: AppBar(title: const Text('EPUB')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${_controller.error ?? 'Unable to open EPUB'}'))));
    final book = _controller.book!;
    return Scaffold(
      appBar: AppBar(title: Text(book.title, overflow: TextOverflow.ellipsis), actions: [
        IconButton(tooltip: _bookmarked ? '取消书签' : '书签', onPressed: _toggleBookmark, icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: '阅读器面板', onPressed: _openSettings, icon: const Icon(Icons.tune_rounded)),
      ]),
      body: EpubReaderView(
        key: ValueKey('${_controller.chapterIndex}:${_controller.initialProgress}:${_controller.initialFragment}:${_settings.toJson()}'),
        archive: _controller.archive!, chapterIndex: _controller.chapterIndex, fragment: _controller.initialFragment, initialProgress: _controller.initialProgress, settings: _settings,
        onPositionChanged: (href, progress) => _controller.updateProgress(href, progress), onPageBoundary: _handleBoundary, onSelectionChanged: _openLookup,
      ),
    );
  }

  String _chapterTitle(int index) {
    final spine = _controller.archive!.book.spine[index];
    final item = _controller.archive!.book.manifestById(spine.idref);
    return item?.href.split('/').last ?? 'Chapter ${index + 1}';
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
