import 'dart:isolate';
import 'dart:convert';

import '../../../core/ffi/medical_core.dart';

class ReaderSearchResult {
  final int pageIndex;

  final int hitCount;

  final List<String> contexts;

  const ReaderSearchResult({
    required this.pageIndex,
    required this.hitCount,
    required this.contexts,
  });
}

class ReaderSearchService {
  const ReaderSearchService();

  Future<List<ReaderSearchResult>> search({
    required String documentId,
    required String documentPath,
    required String query,
    int maxResults = 50,
  }) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final encoded = await Isolate.run(
      () => _searchInIsolate(
        documentId,
        documentPath,
        normalizedQuery,
        maxResults,
      ),
      debugName: 'medical_reader_pdf_search',
    );

    if (encoded.isEmpty) {
      return const [];
    }

    return _parseResults(encoded);
  }

  static String _searchInIsolate(
    String documentId,
    String documentPath,
    String query,
    int maxResults,
  ) {
    final core = MedicalCore();

    final document = core.openBook(id: documentId, path: documentPath);

    try {
      return document.searchBook(query: query, maxResults: maxResults);
    } finally {
      document.close();
    }
  }

  List<ReaderSearchResult> _parseResults(String encoded) {
    final decoded = jsonDecode(encoded);

    if (decoded is! List) {
      return const [];
    }

    final results = <ReaderSearchResult>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final pageIndex = item['pageIndex'];

      final hitCount = item['hitCount'];

      final rawContexts = item['contexts'];

      if (pageIndex is! num || hitCount is! num) {
        continue;
      }

      final contexts = <String>[];

      if (rawContexts is List) {
        for (final context in rawContexts) {
          if (context is String && context.trim().isNotEmpty) {
            contexts.add(context);
          }
        }
      }

      results.add(
        ReaderSearchResult(
          pageIndex: pageIndex.toInt(),
          hitCount: hitCount.toInt(),
          contexts: contexts,
        ),
      );
    }

    return results;
  }
}
