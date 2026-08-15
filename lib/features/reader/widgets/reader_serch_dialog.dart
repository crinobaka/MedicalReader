import 'package:flutter/material.dart';

import '../services/reader_search_service.dart';

class ReaderSearchDialog extends StatefulWidget {
  final ReaderSearchService searchService;

  final String documentId;

  final String documentPath;

  final int currentPage;

  const ReaderSearchDialog({
    super.key,
    required this.searchService,
    required this.documentId,
    required this.documentPath,
    required this.currentPage,
  });

  @override
  State<ReaderSearchDialog> createState() => _ReaderSearchDialogState();
}

class _ReaderSearchDialogState extends State<ReaderSearchDialog> {
  late final TextEditingController _controller;

  List<ReaderSearchResult> _results = const [];

  bool _searching = false;

  Object? _error;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();

    if (query.isEmpty || _searching) {
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });

    try {
      final results = await widget.searchService.search(
        documentId: widget.documentId,
        documentPath: widget.documentPath,
        query: query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _searching = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索 PDF'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '输入英文、中文或缩写',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '搜索',
                  onPressed: _searching ? null : _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) {
                _search();
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('搜索失败：$_error', textAlign: TextAlign.center));
    }

    if (_results.isEmpty) {
      return const Center(child: Text('输入关键词后开始搜索'));
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];

        final page = result.pageIndex + 1;

        final isCurrentPage = result.pageIndex == widget.currentPage;

        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text('第 $page 页'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.bookTreePath.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  result.bookTreePath.join(' / '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 4),
              Text('命中 ${result.hitCount} 次'),
              if (result.contexts.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...result.contexts.map(
                  (context) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      context,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: isCurrentPage
              ? const Chip(label: Text('当前页'))
              : const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).pop(result);
          },
        );
      },
    );
  }
}
