import 'dart:isolate';
import 'dart:convert';

import '../../../core/ffi/medical_core.dart';

class ReaderSearchHit {
  final double x;
  final double y;
  final double width;
  final double height;

  const ReaderSearchHit({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ReaderSearchResult {
  final int pageIndex;

  final int hitCount;

  final List<String> contexts;

  final List<ReaderSearchHit> hits;

  final List<String> bookTreePath;

  const ReaderSearchResult({
    required this.pageIndex,
    required this.hitCount,
    required this.contexts,
    required this.hits,
    this.bookTreePath = const [],
  });

  ReaderSearchResult copyWith({
    List<String>? bookTreePath,
  }) {
    return ReaderSearchResult(
      pageIndex: pageIndex,
      hitCount: hitCount,
      contexts: contexts,
      hits: hits,
      bookTreePath: bookTreePath ?? this.bookTreePath,
    );
  }
}

class ReaderSearchService {
  const ReaderSearchService();

  Future<List<ReaderSearchResult>> search({
    required String documentId,
    required String documentPath,
    required String query,
    int maxResults = 50,
    int contextBefore = 80,
    int contextAfter = 80,
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
        contextBefore,
        contextAfter,
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
    int contextBefore,
    int contextAfter,
  ) {
    final core = MedicalCore();

    final document = core.openBook(id: documentId, path: documentPath);

    try {
      return document.searchBook(query: query, maxResults: maxResults, contextBefore: contextBefore, contextAfter: contextAfter);
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

      final rawHits = item['hits'];

      final rawBookTreePath = item['bookTreePath'];

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

      final bookTreePath = <String>[];

      if (rawBookTreePath is List) {
        for (final node in rawBookTreePath) {
          if (node is String && node.trim().isNotEmpty) {
            bookTreePath.add(node);
          }
        }
      }

      final hits = <ReaderSearchHit>[];

      if (rawHits is List) {
        for (final item in rawHits) {
          if (item is! Map) {
            continue;
          }

          final x = item['x'];
          final y = item['y'];
          final width = item['width'];
          final height = item['height'];

          if (x is! num ||
              y is! num ||
              width is! num ||
              height is! num) {
            continue;
          }

          hits.add(
            ReaderSearchHit(
              x: x.toDouble(),
              y: y.toDouble(),
              width: width.toDouble(),
              height: height.toDouble(),
            ),
          );
        }
      }

      results.add(
        ReaderSearchResult(
          pageIndex: pageIndex.toInt(),
          hitCount: hitCount.toInt(),
          contexts: contexts,
          hits: hits,
          bookTreePath: bookTreePath,
        ),
      );
    }

    return results;
  }
}
