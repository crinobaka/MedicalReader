import 'package:flutter/material.dart';

import '../services/reader_search_service.dart';
import '../models/reader_document_session.dart';
import '../models/book_tree_index.dart';
import '../models/book_page_mapping.dart';
import '../models/book_template.dart';

class ReaderSearchDialog extends StatefulWidget {
  final ReaderSearchService searchService;
  final ReaderDocumentSession? session;
  final String documentId;
  final String documentPath;
  final int currentPage;
  final BookTreeIndex bookTreeIndex;
  final BookPageMapping bookPageMapping;
  final BookTemplate? bookTemplate;
  final Map<String, dynamic> searchContext;

  const ReaderSearchDialog({
    super.key,
    required this.searchService,
    required this.documentId,
    required this.documentPath,
    required this.currentPage,
    required this.bookTreeIndex,
    required this.bookPageMapping,
    this.session,
    this.bookTemplate,
    this.searchContext = const {},
  });

  @override
  State<ReaderSearchDialog> createState() => _ReaderSearchDialogState();
}

class _ReaderSearchDialogState extends State<ReaderSearchDialog> {
  late final TextEditingController _controller;
  List<ReaderSearchResult> _results = const [];
  bool _searching = false;
  Object? _error;

  bool get _showContext => widget.searchContext['showContext'] as bool? ?? true;
  bool get _showChapter => widget.searchContext['showChapter'] as bool? ?? true;
  bool get _showBookPage => widget.searchContext['showBookPage'] as bool? ?? true;

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
      final searchContext = widget.searchContext;
      final contextBefore = (searchContext['contextBefore'] as num?)?.toInt() ?? 80;
      final contextAfter = (searchContext['contextAfter'] as num?)?.toInt() ?? 120;

      final results = await widget.searchService.search(
        documentId: widget.documentId,
        documentPath: widget.documentPath,
        session: widget.session,
        query: query,
        contextBefore: contextBefore,
        contextAfter: contextAfter,
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
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
        final bookPage = widget.bookPageMapping.bookPageForPdfPage(result.pageIndex);
        final isCurrentPage = result.pageIndex == widget.currentPage;
        final bookTreePath = widget.bookTreeIndex.findPathForPage(result.pageIndex);
        final chapterLabel = bookTreePath.isEmpty ? null : bookTreePath.map((node) => node.name).join(' / ');
        final pageLabel = _showBookPage && bookPage != null
            ? '书籍第 $bookPage 页 · PDF 第 $page 页'
            : 'PDF 第 $page 页';

        return ListTile(
          leading: Icon(result.regionId == null ? Icons.description_outlined : Icons.crop),
          title: Text(pageLabel),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.regionId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('裁剪区域 ${result.regionId}'),
                ),
              if (_showChapter && chapterLabel != null) ...[
                const SizedBox(height: 4),
                Text(chapterLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text('命中 ${result.hitCount} 次'),
              if (_showContext && result.contexts.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...result.contexts.map(
                  (context) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(context, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ],
          ),
          trailing: isCurrentPage ? const Chip(label: Text('当前页')) : const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pop(result),
        );
      },
    );
  }
}
