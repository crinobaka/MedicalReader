import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../models/reader_annotation.dart';
import '../providers/reader_annotation_provider.dart';

class ReaderAnnotationsPage extends ConsumerStatefulWidget {
  const ReaderAnnotationsPage({super.key, this.document});
  final LibraryDocument? document;
  @override
  ConsumerState<ReaderAnnotationsPage> createState() => _ReaderAnnotationsPageState();
}

class _ReaderAnnotationsPageState extends ConsumerState<ReaderAnnotationsPage> {
  String _query = '';
  ReaderAnnotationType? _filter;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.document == null ? '批注库' : '本书批注'),
          actions: [
            PopupMenuButton<ReaderAnnotationType?>(
              onSelected: (value) => setState(() => _filter = value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('全部')),
                for (final type in ReaderAnnotationType.values)
                  PopupMenuItem(value: type, child: Text(_label(type))),
              ],
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索批注、笔记和高亮…', border: OutlineInputBorder()),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: FutureBuilder<List<LibraryDocument>>(
            future: _documents(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('加载失败：${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return _buildList(snapshot.data!);
            },
          )),
        ]),
      );

  Widget _buildList(List<LibraryDocument> books) {
    final targets = widget.document == null ? books : [widget.document!];
    final sections = <Widget>[];
    for (final book in targets) {
      final items = ref.watch(readerAnnotationsProvider(book));
      final visible = items.where(_matches).toList(growable: false);
      if (visible.isEmpty) continue;
      sections.add(ExpansionTile(
        initiallyExpanded: true,
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${visible.length} 条'),
        children: [for (final item in visible) _annotationTile(context, item)],
      ));
    }
    if (sections.isEmpty) return const Center(child: Text('没有匹配的批注'));
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: sections);
  }

  bool _matches(ReaderAnnotation item) {
    if (_filter != null && item.type != _filter) return false;
    final query = _query.trim().toLowerCase();
    return query.isEmpty || item.content.toLowerCase().contains(query) || item.title.toLowerCase().contains(query);
  }

  Widget _annotationTile(BuildContext context, ReaderAnnotation item) => ListTile(
        leading: Icon(_icon(item.type)),
        title: Text(item.title.isEmpty ? _label(item.type) : item.title),
        subtitle: Text(item.content.isEmpty ? '第 ${item.pageIndex + 1} 页' : item.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: Text('P${item.pageIndex + 1}'),
        onTap: () => Navigator.pop(context, item),
      );

  Future<List<LibraryDocument>> _documents() async {
    final repository = ref.read(libraryRepositoryProvider);
    await repository.initialize();
    return repository.getDocuments();
  }

  IconData _icon(ReaderAnnotationType type) => switch (type) {
        ReaderAnnotationType.highlight => Icons.highlight,
        ReaderAnnotationType.note => Icons.sticky_note_2_outlined,
        ReaderAnnotationType.bookmark => Icons.bookmark_outline,
        ReaderAnnotationType.tag => Icons.sell_outlined,
        ReaderAnnotationType.ink => Icons.draw_outlined,
      };

  String _label(ReaderAnnotationType type) => switch (type) {
        ReaderAnnotationType.highlight => '高亮',
        ReaderAnnotationType.note => '笔记',
        ReaderAnnotationType.bookmark => '书签',
        ReaderAnnotationType.tag => '标签',
        ReaderAnnotationType.ink => '手绘',
      };
}
