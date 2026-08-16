import 'book_tree_index.dart';
import 'book_tree_node.dart';

class BookPageMapping {
  final BookTreeIndex index;

  final Map<int, int> explicitBookToPdf;

  final Map<int, int> explicitPdfToBook;

  const BookPageMapping({
    required this.index,
    this.explicitBookToPdf = const {},
    this.explicitPdfToBook = const {},
  });

  int? bookPageForPdfPage(int pageIndex) {
    final explicit = explicitPdfToBook[pageIndex + 1];

    if (explicit != null) {
      return explicit;
    }

    if (!index.isValidPageIndex(pageIndex)) {
      return null;
    }

    final path = index.findPathForPage(pageIndex);

    if (path.isEmpty) {
      return null;
    }

    for (final node in path.reversed) {
      final pdfStart = node.pageStart;
      final pdfEnd = node.pageEnd;
      final bookStart = node.bookPageStart;
      final bookEnd = node.bookPageEnd;

      if (pdfStart == null || bookStart == null) {
        continue;
      }

      if (pdfEnd == null || bookEnd == null) {
        return bookStart + (pageIndex + 1 - pdfStart);
      }

      final pdfLength = pdfEnd - pdfStart;
      final bookLength = bookEnd - bookStart;

      if (pdfLength < 0 || bookLength < 0) {
        continue;
      }

      if (pdfLength == 0) {
        return bookStart;
      }

      final offset = pageIndex + 1 - pdfStart;

      if (offset < 0 || offset > pdfLength) {
        continue;
      }

      if (pdfLength == bookLength) {
        return bookStart + offset;
      }

      return bookStart + offset.clamp(0, bookLength);
    }

    return null;
  }

  BookTreeNode? nodeForPdfPage(int pageIndex) {
    return index.findNodeForPage(pageIndex);
  }

  int? pdfPageForBookPage(int bookPage) {
    final explicit = explicitBookToPdf[bookPage];

    if (explicit != null) {
      return explicit - 1;
    }

    if (bookPage <= 0) {
      return null;
    }

    for (final node in index.nodes) {
      final result = _findPdfPageForBookPage(node, bookPage);

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  int? _findPdfPageForBookPage(BookTreeNode node, int bookPage) {
    final bookStart = node.bookPageStart;
    final bookEnd = node.bookPageEnd;

    if (bookStart != null &&
        bookEnd != null &&
        bookPage >= bookStart &&
        bookPage <= bookEnd) {
      final pdfStart = node.pageStart;
      final pdfEnd = node.pageEnd;

      if (pdfStart != null && pdfEnd != null) {
        final bookLength = bookEnd - bookStart;
        final pdfLength = pdfEnd - pdfStart;

        if (bookLength == 0) {
          return pdfStart - 1;
        }

        final offset = bookPage - bookStart;

        if (bookLength == pdfLength) {
          return pdfStart - 1 + offset;
        }

        final ratio = offset / bookLength;
        final pdfOffset = (ratio * pdfLength).round();

        return (pdfStart - 1 + pdfOffset).clamp(pdfStart - 1, pdfEnd - 1);
      }
    }

    for (final child in node.children) {
      final result = _findPdfPageForBookPage(child, bookPage);

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  factory BookPageMapping.fromTemplate({
    required BookTreeIndex index,
    required Map<String, dynamic> config,
  }) {
    final explicitBookToPdf = <int, int>{};
    final explicitPdfToBook = <int, int>{};

    final explicit = config['explicit'];

    if (explicit is Map) {
      for (final entry in explicit.entries) {
        final bookPage = int.tryParse(entry.key.toString());

        if (bookPage == null) {
          continue;
        }

        final pdfPage = entry.value is num
            ? (entry.value as num).toInt()
            : int.tryParse(entry.value.toString());

        if (pdfPage == null || pdfPage <= 0) {
          continue;
        }

        explicitBookToPdf[bookPage] = pdfPage;
        explicitPdfToBook[pdfPage] = bookPage;
      }
    }

    return BookPageMapping(
      index: index,
      explicitBookToPdf: Map.unmodifiable(explicitBookToPdf),
      explicitPdfToBook: Map.unmodifiable(explicitPdfToBook),
    );
  }
}
