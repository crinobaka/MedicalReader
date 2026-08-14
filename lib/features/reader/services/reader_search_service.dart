import 'dart:isolate';

import '../../../core/ffi/medical_core.dart';

class ReaderSearchResult {
  final int pageIndex;

  final int hitCount;

  const ReaderSearchResult({
    required this.pageIndex,
    required this.hitCount,
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

    final document = core.openBook(
      id: documentId,
      path: documentPath,
    );

    try {
      return document.searchBook(
        query: query,
        maxResults: maxResults,
      );
    } finally {
      document.close();
    }
  }

  List<ReaderSearchResult> _parseResults(
    String encoded,
  ) {
    final results = <ReaderSearchResult>[];

    for (final item in encoded.split(';')) {
      if (item.isEmpty) {
        continue;
      }

      final separator =
          item.indexOf(':');

      if (separator <= 0 ||
          separator >= item.length - 1) {
        continue;
      }

      final pageIndex =
          int.tryParse(
        item.substring(
          0,
          separator,
        ),
      );

      final hitCount =
          int.tryParse(
        item.substring(
          separator + 1,
        ),
      );

      if (pageIndex == null ||
          hitCount == null) {
        continue;
      }

      results.add(
        ReaderSearchResult(
          pageIndex: pageIndex,
          hitCount: hitCount,
        ),
      );
    }

    return results;
  }
}