import 'package:flutter/foundation.dart';

import '../../library/models/library_document.dart';
import '../../reader/services/reader_search_service.dart';
import '../services/search_history_service.dart';

/// SearchPage 的业务状态。
///
/// 搜索顺序保持简单明确：先做书名/文件名/元数据匹配；对 PDF 再做
/// 文本全文检索。全文检索由 ReaderSearchService 放到 isolate 中执行，
/// 不让大文档搜索阻塞 Flutter UI。
class SearchPageController extends ChangeNotifier {
  SearchPageController({SearchHistoryService? historyService})
      : _historyService = historyService ?? SearchHistoryService();

  final SearchHistoryService _historyService;
  final ReaderSearchService _readerSearchService = const ReaderSearchService();

  String query = '';
  List<String> history = const [];
  List<SearchPageResult> results = const [];
  bool loadingHistory = true;
  bool searching = false;

  Future<void> initialize() async {
    final loaded = await _historyService.load();
    history = loaded;
    loadingHistory = false;
    notifyListeners();
  }

  Future<void> search(
    String value,
    List<LibraryDocument> documents,
  ) async {
    final nextQuery = value.trim();
    if (nextQuery.isEmpty) return;

    query = nextQuery;
    history = await _historyService.add(nextQuery);
    searching = true;
    results = const [];
    notifyListeners();

    final matches = <SearchPageResult>[];
    for (final document in documents) {
      if (!document.isPdf) {
        if (_matchesMetadata(document, nextQuery)) {
          matches.add(SearchPageResult(document: document));
        }
        continue;
      }

      try {
        final hits = await _readerSearchService.search(
          documentId: document.file.id,
          documentPath: document.file.path,
          query: nextQuery,
          maxResults: 50,
        );
        if (hits.isNotEmpty) {
          matches.add(
            SearchPageResult(
              document: document,
              fullTextHits: hits,
            ),
          );
          continue;
        }
      } catch (_) {
        // A document that cannot be indexed must not break the whole library
        // search. Metadata fallback below still keeps the book discoverable.
      }

      if (_matchesMetadata(document, nextQuery)) {
        matches.add(SearchPageResult(document: document));
      }
    }

    results = matches;
    searching = false;
    notifyListeners();
  }

  void clearQuery() {
    if (query.isEmpty && results.isEmpty) return;
    query = '';
    results = const [];
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _historyService.clear();
    history = const [];
    notifyListeners();
  }

  bool _matchesMetadata(LibraryDocument document, String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (document.title.toLowerCase().contains(q)) return true;
    if (document.file.name.toLowerCase().contains(q)) return true;
    return document.metadata.values.any(
      (item) => item.toString().toLowerCase().contains(q),
    );
  }
}

class SearchPageResult {
  final LibraryDocument document;
  final List<ReaderSearchResult> fullTextHits;

  const SearchPageResult({
    required this.document,
    this.fullTextHits = const [],
  });

  int get hitCount =>
      fullTextHits.fold<int>(0, (sum, item) => sum + item.hitCount);

  String? get firstContext {
    for (final result in fullTextHits) {
      for (final context in result.contexts) {
        if (context.trim().isNotEmpty) return context.trim();
      }
    }
    return null;
  }

  int? get firstPage =>
      fullTextHits.isEmpty ? null : fullTextHits.first.pageIndex;
}
