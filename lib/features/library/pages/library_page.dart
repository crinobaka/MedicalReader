import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/pages/reader_page.dart';
import '../models/library_collection.dart';
import '../models/library_document.dart';
import '../providers/library_provider.dart';
import '../providers/library_repository_provider.dart';
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
  List<LibraryCollection> _collections = const [];
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCollections();
      await _refresh();
    });
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

  Future<void> _loadCollections() async {
    final items = await ref.read(libraryRepositoryProvider).getCollections();
    if (!mounted) return;
    setState(() {
      _collections = items;
      if (_selectedCollectionId != null && !items.any((x) => x.id == _selectedCollectionId)) {
        _selectedCollectionId = null;
      }
    });
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
    final allDocuments = ref.watch(libraryProvider);
    final documents = _sortedDocuments(_filterDocuments(allDocuments));
    final notifier = ref.read(libraryProvider.notifier);
    final selectedName = _selectedCollectionId == null
        ? '全部书籍'
        : (_collections.where((x) => x.id == _selectedCollectionId).firstOrNull?.name ?? '全部书籍');

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedName),
        actions: [
          PopupMenuButton<String>(
            tooltip: '书架分类',
            icon: const Icon(Icons.folder_copy_outlined),
            onSelected: (value) async {
              if (value == '__manage__') {
                await _manageCollections();
              } else {
                setState(() => _selectedCollectionId = value == '__all__' ? null : value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '__all__', child: Text('全部书籍')),
              ..._collections.map((x) => PopupMenuItem(value: x.id, child: Text(x.name))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '__manage__', child: Text('管理书架')),
            ],
          ),
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
          IconButton(tooltip: '刷新文件库', onPressed: _refreshing ? null : _refresh, icon: const Icon(Icons.refresh)),
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
                    child: Row(children: [const Icon(Icons.folder, size: 18), const SizedBox(width: 8), Expanded(child: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis))]),
                  );
                },
              ),
            ),
            if (documents.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_selectedCollectionId == null ? '还没有导入医学 PDF' : '这个书架还没有书籍'))))
            else
              _buildDocuments(documents),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _import, icon: const Icon(Icons.add), label: const Text('导入 PDF')),
    );
  }

  List<LibraryDocument> _filterDocuments(List<LibraryDocument> documents) {
    final id = _selectedCollectionId;
    if (id == null) return documents;
    return documents.where((document) {
      final raw = document.metadata['collection_ids'];
      return raw is List && raw.any((x) => x.toString() == id);
    }).toList(growable: false);
  }

  IconData get _viewIcon => switch (_viewMode) {
        _LibraryViewMode.list => Icons.view_list_outlined,
        _LibraryViewMode.compact => Icons.view_agenda_outlined,
        _LibraryViewMode.grid => Icons.grid_view_outlined,
      };

  List<LibraryDocument> _sortedDocuments(List<LibraryDocument> documents) {
    final sorted = [...documents];
    int compare(LibraryDocument a, LibraryDocument b) => switch (_sortMode) {
          _LibrarySortMode.recentRead => _readTime(b).compareTo(_readTime(a)),
          _LibrarySortMode.recentAdded => b.addedAt.compareTo(a.addedAt),
          _LibrarySortMode.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          _LibrarySortMode.progress => _progress(b).compareTo(_progress(a)),
          _LibrarySortMode.pages => (b.pages ?? -1).compareTo(a.pages ?? -1),
          _LibrarySortMode.size => b.file.size.compareTo(a.file.size),
        };
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
          delegate: SliverChildBuilderDelegate((context, index) => _buildDocumentCard(documents[index], layout), childCount: documents.length),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisExtent: 310, crossAxisSpacing: 2, mainAxisSpacing: 2),
        ),
      );
    }
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildDocumentCard(documents[index], layout), childCount: documents.length));
  }

  Widget _buildDocumentCard(LibraryDocument document, DocumentCardLayout layout) => DocumentCard(
        document: document,
        layout: layout,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderPage(document: document))),
        onManageCollections: () => _editDocumentCollections(document),
        onDelete: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除书籍'),
              content: Text('确定删除「${document.title}」及其 Library 文件吗？'),
              actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除'))],
            ),
          );
          if (confirmed == true) await ref.read(libraryProvider.notifier).removeDocument(document.id);
        },
      );

  Future<void> _editDocumentCollections(LibraryDocument document) async {
    final repository = ref.read(libraryRepositoryProvider);
    var selected = (await repository.getDocumentCollectionIds(document.id)).toSet();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
            title: Text('整理「${document.title}」'),
            content: SizedBox(
              width: 420,
              child: _collections.isEmpty
                  ? const Text('还没有书架，请先创建一个。')
                  : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final collection in _collections)
                        CheckboxListTile(
                          value: selected.contains(collection.id),
                          title: Text(collection.name),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) => setDialogState(() {
                            if (value == true) selected.add(collection.id); else selected.remove(collection.id);
                          }),
                        ),
                    ])),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
              FilledButton(onPressed: () async {
                await repository.setDocumentCollections(documentId: document.id, collectionIds: selected.toList());
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              }, child: const Text('保存')),
            ],
          )),
    );
    if (result == true && mounted) await _refresh();
  }

  Future<void> _manageCollections() async {
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
      Future<void> refreshDialog() async {
        await _loadCollections();
        setDialogState(() {});
      }
      return AlertDialog(
        title: const Text('管理书架'),
        content: SizedBox(
          width: 420,
          child: _collections.isEmpty
              ? const Text('还没有创建书架。')
              : ListView(shrinkWrap: true, children: [for (final collection in _collections) ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(collection.name),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), tooltip: '重命名', onPressed: () async {
                      final name = await _nameDialog(collection.name, title: '重命名书架');
                      if (name != null) { await ref.read(libraryRepositoryProvider).renameCollection(collection.id, name); await refreshDialog(); }
                    }),
                    IconButton(icon: const Icon(Icons.delete_outline), tooltip: '删除', onPressed: () async {
                      final yes = await _confirmDeleteCollection(collection.name);
                      if (yes == true) { await ref.read(libraryRepositoryProvider).deleteCollection(collection.id); if (_selectedCollectionId == collection.id) _selectedCollectionId = null; await refreshDialog(); }
                    }),
                  ]),)]),
        ),
        actions: [
          TextButton(onPressed: () async {
            final name = await _nameDialog('', title: '新建书架');
            if (name != null) { await ref.read(libraryRepositoryProvider).createCollection(name); await refreshDialog(); }
          }, child: const Text('新建书架')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('完成')),
        ],
      );
    }));
    if (mounted) { await _loadCollections(); await _refresh(); }
  }

  Future<String?> _nameDialog(String initial, {required String title}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(controller: controller, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: '书架名称')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(context, value); }, child: const Text('保存'))],
        ));
    controller.dispose();
    return result;
  }

  Future<bool?> _confirmDeleteCollection(String name) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除书架'),
          content: Text('删除「$name」不会删除书籍，只会解除书籍与该书架的关联。确定继续吗？'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除'))],
        ),
      );
}