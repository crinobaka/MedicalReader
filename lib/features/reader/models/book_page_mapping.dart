import 'book_tree_index.dart';
import 'book_tree_node.dart';

class BookPageMapping {
  final BookTreeIndex index;

  const BookPageMapping({required this.index});

  int? bookPageForPdfPage(int pageIndex) {
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
}
