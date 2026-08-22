import 'dart:isolate';
import 'dart:convert';

import '../../../core/ffi/medical_core.dart';
import '../models/reader_document_session.dart';
import '../models/reader_search_hit.dart';

class ReaderSearchResult {
  final int pageIndex;
  final int hitCount;
  final List<String> contexts;
  final List<ReaderSearchHit> hits;
  final List<String> bookTreePath;
  final String? regionId;

  const ReaderSearchResult({
    required this.pageIndex,
    required this.hitCount,
    required this.contexts,
    required this.hits,
    this.bookTreePath = const [],
    this.regionId,
  });

  ReaderSearchResult copyWith({
    List<String>? bookTreePath,
    String? regionId,
  }) {
    return ReaderSearchResult(
      pageIndex: pageIndex,
      hitCount: hitCount,
      contexts: contexts,
      hits: hits,
      bookTreePath: bookTreePath ?? this.bookTreePath,
      regionId: regionId ?? this.regionId,
    );
  }
}

class ReaderSearchService {
  const ReaderSearchService();

  Future<List<ReaderSearchResult>> search({
    String? documentId,
    String? documentPath,
    ReaderDocumentSession? session,
    required String query,
    int maxResults = 50,
    int contextBefore = 80,
    int contextAfter = 80,
  }) async {
    final normalizedQuery = query.trim();
    final effectiveDocumentId = session?.sourceDocumentId ?? documentId;
    final effectiveDocumentPath = session?.sourcePath ?? documentPath;

    if (normalizedQuery.isEmpty ||
        effectiveDocumentId == null ||
        effectiveDocumentPath == null) {
      return const [];
    }

    final encoded = await Isolate.run(
      () => _searchInIsolate(
        effectiveDocumentId,
        effectiveDocumentPath,
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

    final results = _parseResults(encoded);

    if (session == null) {
      return results;
    }

    return results.map((result) {
      String? regionId;
      for (final hit in result.hits) {
        final region = session.regionForHit(result.pageIndex, hit);
        if (region != null) {
          regionId = region.id;
          break;
        }
      }
      return result.copyWith(regionId: regionId);
    }).toList(growable: false);
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
      return document.searchBook(
        query: query,
        maxResults: maxResults,
        contextBefore: contextBefore,
        contextAfter: contextAfter,
      );
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
        for (final rawHit in rawHits) {
          if (rawHit is! Map) {
            continue;
          }
          final x = rawHit['x'];
          final y = rawHit['y'];
          final width = rawHit['width'];
          final height = rawHit['height'];
          if (x is! num || y is! num || width is! num || height is! num) {
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
