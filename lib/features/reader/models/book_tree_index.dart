import 'book_tree_node.dart';

class BookTreeIndex {
  final List<BookTreeNode> nodes;

  final int pageCount;

  const BookTreeIndex({
    required this.nodes,
    required this.pageCount,
  });

  bool get isEmpty => nodes.isEmpty;

  bool get isNotEmpty => nodes.isNotEmpty;

  bool isValidPageIndex(int pageIndex) {
    return pageIndex >= 0 && pageIndex < pageCount;
  }

  BookTreeNode? findNodeForPage(int pageIndex) {
    if (!isValidPageIndex(pageIndex)) {
      return null;
    }

    for (final node in nodes) {
      final result = node.findNodeForPage(pageIndex);

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  List<BookTreeNode> findPathForPage(int pageIndex) {
    if (!isValidPageIndex(pageIndex)) {
      return const [];
    }

    for (final node in nodes) {
      final path = <BookTreeNode>[];

      if (_collectPath(node, pageIndex, path)) {
        return List.unmodifiable(path);
      }
    }

    return const [];
  }

  bool _collectPath(
    BookTreeNode node,
    int pageIndex,
    List<BookTreeNode> path,
  ) {
    if (!node.containsPage(pageIndex)) {
      return false;
    }

    path.add(node);

    for (final child in node.children) {
      if (_collectPath(child, pageIndex, path)) {
        return true;
      }
    }

    return true;
  }

  BookTreeNode? findNodeById(String id) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final node in nodes) {
      final result = _findNodeById(node, normalizedId);

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  BookTreeNode? _findNodeById(
    BookTreeNode node,
    String id,
  ) {
    if (node.id == id) {
      return node;
    }

    for (final child in node.children) {
      final result = _findNodeById(child, id);

      if (result != null) {
        return result;
      }
    }

    return null;
  }
}