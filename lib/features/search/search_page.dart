import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/models/library_document.dart';
import '../library/providers/library_provider.dart';
import '../reader/pages/reader_page.dart';
import 'services/search_history_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _historyService = SearchHistoryService();
  List<String> _history = const [];
  String _query = '';

  @override
  void initState() { super.initState(); _loadHistory(); }

  Future<void> _loadHistory() async {
    final history = await _historyService.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    final history = await _historyService.add(query);
    if (mounted) setState(() { _query = query; _history = history; });
  }

  Future<void> _clearHistory() async {
    await _historyService.clear();
    if (mounted) setState(() => _history = const []);
  }

  List<LibraryDocument> _results(List<LibraryDocument> documents) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return const [];
    return documents.where((document) =>
      document.title.toLowerCase().contains(q) ||
      document.file.name.toLowerCase().contains(q) ||
      document.metadata.values.any((value) => value.toString().toLowerCase().contains(q))
    ).toList(growable: false);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(libraryProvider);
    final results = _results(documents);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: SearchBar(
                controller: _controller,
                hintText: '搜索书名、文件名或元数据',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_controller.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); setState(() => _query = ''); }),
                  IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
                ],
                onSubmitted: (_) => _search(),
              ),
            ),
          ),
          if (_query.isEmpty && _history.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 4), child: Row(children: [const Expanded(child: Text('最近搜索', style: TextStyle(fontWeight: FontWeight.w600))), TextButton(onPressed: _clearHistory, child: const Text('清空'))]))),
            SliverList.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(_history[index]),
                trailing: const Icon(Icons.north_west, size: 18),
                onTap: () => _search(_history[index]),
              ),
            ),
          ] else if (_query.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('找到 ${results.length} 项'))),
            if (results.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('没有找到匹配内容')))
            else
              SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final document = results[index];
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(document.title),
                    subtitle: Text(document.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(document: document))),
                  );
                },
              ),
          ] else
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('输入关键词开始搜索'))),
        ],
      ),
    );
  }
}
