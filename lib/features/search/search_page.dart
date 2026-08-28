import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/models/library_document.dart';
import '../library/providers/library_provider.dart';
import '../reader/pages/reader_page.dart';
import 'controllers/search_page_controller.dart';

/// 搜索入口：只组装输入、结果列表和导航，不持有搜索业务状态。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final SearchPageController _controller;
  late final TextEditingController _queryController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = SearchPageController()..initialize();
    _queryController = TextEditingController();
    _searchFocusNode = FocusNode();
    _queryController.addListener(_onQueryTextChanged);
  }

  void _onQueryTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _queryController.text).trim();
    if (query.isEmpty) return;
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    await _controller.search(query);
    if (mounted) _searchFocusNode.unfocus();
  }

  void _clearQuery() {
    _queryController.clear();
    _controller.clearQuery();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryTextChanged);
    _queryController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(libraryProvider);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final results = _controller.filterDocuments(documents);
        final hasQuery = _controller.query.isNotEmpty;
        return Scaffold(
          appBar: AppBar(title: const Text('搜索')),
          body: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SearchBar(
                    controller: _queryController,
                    focusNode: _searchFocusNode,
                    hintText: '搜索书名、文件名或元数据',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_queryController.text.isNotEmpty)
                        IconButton(
                          tooltip: '清除',
                          icon: const Icon(Icons.clear),
                          onPressed: _clearQuery,
                        ),
                      IconButton(
                        tooltip: '搜索',
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _search(),
                      ),
                    ],
                    onSubmitted: (value) => _search(value),
                  ),
                ),
              ),
              if (!hasQuery && _controller.history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('最近搜索', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        TextButton.icon(
                          onPressed: _controller.clearHistory,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: _controller.history.length,
                  itemBuilder: (context, index) {
                    final item = _controller.history[index];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(item),
                      trailing: const Icon(Icons.north_west, size: 18),
                      onTap: () => _search(item),
                    );
                  },
                ),
              ] else if (hasQuery) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('“${_controller.query}” · 找到 ${results.length} 项'),
                  ),
                ),
                if (results.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('没有找到匹配内容')),
                  )
                else
                  SliverList.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) => _SearchResultTile(document: results[index]),
                  ),
              ] else if (!_controller.loadingHistory)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('输入关键词开始搜索')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.document});
  final LibraryDocument document;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(document.title),
      subtitle: Text(document.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderPage(document: document)),
      ),
    );
  }
}
