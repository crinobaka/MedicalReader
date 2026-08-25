import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/pages/reader_page.dart';
import '../models/library_document.dart';
import '../providers/library_provider.dart';
import '../widgets/document_card.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> with WidgetsBindingObserver {
  bool _refreshing = false;

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
    final documents = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Library'),
        actions: [
          IconButton(tooltip: '刷新文件库', onPressed: _refreshing ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FutureBuilder<String>(
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
            if (documents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 120, horizontal: 24),
                child: Center(child: Text('还没有导入医学 PDF')),
              )
            else
              ...documents.map(_buildDocumentCard),
            const SizedBox(height: 96),
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

  Widget _buildDocumentCard(LibraryDocument document) {
    return DocumentCard(
      document: document,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderPage(document: document))),
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
        if (confirmed == true) await ref.read(libraryProvider.notifier).removeDocument(document.id);
      },
    );
  }
}
