import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/pages/reader_page.dart';
import '../models/library_document.dart';
import '../providers/library_provider.dart';
import '../widgets/document_card.dart';

enum _LibraryViewMode { list, compact, grid }

enum _LibrarySortMode { recentRead, recentAdded, title, progress, pages, size }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> with WidgetsBindingObserver {
  bool _refreshing = false;
  _LibraryViewMode _viewMode = _LibraryViewMode.list;
  _LibrarySortMode _sortMode = _LibrarySortMode.recentRead;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      await ref.read(libraryProvider.notifier).reload();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _import() async {
    await ref.read(libraryProvider.notifier).addFile();
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final documents = _sortedDocuments(ref.watch(libraryProvider));
    final notifier = ref.read(libraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Library'),
        actions: [
          PopupMenuButton<_LibrarySortMode>(
            tooltip: '排序',
            initialValue: _sortMode,
            onSelected: (value) => setState(() => _sortMode = value),
            icon: const Icon(Icons.sort),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _LibrarySortMode.recentRead, child: Text('最近阅读')),
              PopupMenuItem(value: _LibrarySortMode.recentAdded, child: Text('最近添加')),
              PopupMenuItem(value: _LibrarySortMode.title, child: Text('标题 A–Z')),
              PopupMenuItem(value: _LibrarySortMode.progress, child: Text('阅读进度')),
              PopupMenuItem(value: _LibrarySortMode.pages, child: Text('页数')),
              PopupMenuItem(value: _LibrarySortMode.size, child: Text('文件大小')),
            ],
          ),
          PopupMenuButton<_LibraryViewMode>(
            tooltip: '显示方式',
            initialValue: _viewMode,
            onSelected: (value) => setState(() => _viewMode = value),
            icon: Icon(_viewIcon),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _LibraryViewMode.list, child: Text('详细列表')),
              PopupMenuItem(value: _LibraryViewMode.compact, child: Text('紧凑列表')),
              PopupMenuItem(value: _LibraryViewMode.grid, child: Text('书架网格')),
            ],
          ),
          IconButton(
            tooltip: '刷新文件库',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FutureBuilder<String>(
                future: notifier.libraryPath(),
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  if (path == null) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Row(children: [
                      const Icon(Icons.folder, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  );
                },
              ),
            ),
            if (documents.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('还没有导入医学 PDF'),
                )),
              )
            else
              _buildDocuments(documents),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.add),
        label: const Text('导入 PDF'),
      ),
    );
  }

  IconData get _viewIcon => switch (_viewMode) {
        _LibraryViewMode.list => Icons.view_list_outlined,
        _LibraryViewMode.compact => Icons.view_agenda_outlined,
        _LibraryViewMode.grid => Icons.grid_view_outlined,
      };

  List<LibraryDocument> _sortedDocuments(List<LibraryDocument> documents) {
    final sorted = [...documents];
    int compare(LibraryDocument a, LibraryDocument b) {
      switch (_sortMode) {
        case _LibrarySortMode.recentRead:
          return _readTime(b).compareTo(_readTime(a));
        case _LibrarySortMode.recentAdded:
          return b.addedAt.compareTo(a.addedAt);
        case _LibrarySortMode.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _LibrarySortMode.progress:
          return _progress(b).compareTo(_progress(a));
        case _LibrarySortMode.pages:
          return (b.pages ?? -1).compareTo(a.pages ?? -1);
        case _LibrarySortMode.size:
          return b.file.size.compareTo(a.file.size);
      }
    }
    sorted.sort(compare);
    return sorted;
  }

  DateTime _readTime(LibraryDocument document) {
    final raw = document.metadata['last_read_at'];
    return raw is String ? DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _progress(LibraryDocument document) {
    final pages = document.pages;
    if (pages == null || pages <= 0) return 0;
    final raw = document.metadata['last_page'];
    final lastPage = raw is num ? raw.toDouble() : 0;
    return (lastPage / math.max(1, pages - 1)).clamp(0.0, 1.0).toDouble();
  }

  Widget _buildDocuments(List<LibraryDocument> documents) {
    final layout = switch (_viewMode) {
      _LibraryViewMode.list => DocumentCardLayout.list,
      _LibraryViewMode.compact => DocumentCardLayout.compact,
      _LibraryViewMode.grid => DocumentCardLayout.grid,
    };

    if (_viewMode == _LibraryViewMode.grid) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildDocumentCard(documents[index], layout),
            childCount: documents.length,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            mainAxisExtent: 310,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildDocumentCard(documents[index], layout),
        childCount: documents.length,
      ),
    );
  }

  Widget _buildDocumentCard(LibraryDocument document, DocumentCardLayout layout) {
    return DocumentCard(
      document: document,
      layout: layout,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderPage(document: document)),
      ),
      onDelete: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除书籍'),
            content: Text('确定删除「${document.title}」及其 Library 文件吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(libraryProvider.notifier).removeDocument(document.id);
        }
      },
    );
  }
}
