import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/providers/library_provider.dart';
import 'controllers/search_page_controller.dart';
import 'widgets/search_history_list.dart';
import 'widgets/search_result_tile.dart';

/// Search entry point: coordinates query state and delegates presentation.
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
              if (!hasQuery && _controller.history.isNotEmpty)
                SliverToBoxAdapter(
                  child: SearchHistoryList(
                    history: _controller.history,
                    onSelected: _search,
                    onClear: _controller.clearHistory,
                  ),
                )
              else if (hasQuery) ...[
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
                    itemBuilder: (context, index) => SearchResultTile(document: results[index]),
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
