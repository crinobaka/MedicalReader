import 'package:flutter/foundation.dart';

import '../../library/models/library_document.dart';
import '../services/search_history_service.dart';

/// SearchPage 的交互状态控制器。
///
/// 页面只负责输入和呈现；历史记录、查询状态与库内过滤集中在这里，
/// 以后接入全文搜索时不需要继续膨胀 SearchPage。
class SearchPageController extends ChangeNotifier {
  SearchPageController({SearchHistoryService? historyService})
      : _historyService = historyService ?? SearchHistoryService();

  final SearchHistoryService _historyService;

  String query = '';
  List<String> history = const [];
  bool loadingHistory = true;

  Future<void> initialize() async {
    final loaded = await _historyService.load();
    history = loaded;
    loadingHistory = false;
    notifyListeners();
  }

  Future<void> search(String value) async {
    final nextQuery = value.trim();
    if (nextQuery.isEmpty) return;
    query = nextQuery;
    history = await _historyService.add(nextQuery);
    notifyListeners();
  }

  void clearQuery() {
    if (query.isEmpty) return;
    query = '';
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _historyService.clear();
    history = const [];
    notifyListeners();
  }

  List<LibraryDocument> filterDocuments(List<LibraryDocument> documents) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return documents.where((document) {
      if (document.title.toLowerCase().contains(q)) return true;
      if (document.file.name.toLowerCase().contains(q)) return true;
      return document.metadata.values.any(
        (value) => value.toString().toLowerCase().contains(q),
      );
    }).toList(growable: false);
  }
}
