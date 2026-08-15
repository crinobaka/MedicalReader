class BookTreeNode {
  final String id;

  final String name;

  /// 1-based PDF physical page number.
  final int? pageStart;

  /// 1-based PDF physical page number.
  final int? pageEnd;

  /// 1-based printed page number in the actual book.
  final int? bookPageStart;

  /// 1-based printed page number in the actual book.
  final int? bookPageEnd;

  final List<BookTreeNode> children;

  const BookTreeNode({
    required this.id,
    required this.name,
    this.pageStart,
    this.pageEnd,
    this.bookPageStart,
    this.bookPageEnd,
    this.children = const [],
  });

  factory BookTreeNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];

    final children = <BookTreeNode>[];

    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is Map) {
          children.add(BookTreeNode.fromJson(Map<String, dynamic>.from(child)));
        }
      }
    }

    return BookTreeNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pageStart: _readInt(json['page_start']),
      pageEnd: _readInt(json['page_end']),
      bookPageStart: _readInt(json['book_page_start']),
      bookPageEnd: _readInt(json['book_page_end']),
      children: List.unmodifiable(children),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  bool containsPage(int pageIndex) {
    final page = pageIndex + 1;

    if (pageStart != null && page < pageStart!) {
      return false;
    }

    if (pageEnd != null && page > pageEnd!) {
      return false;
    }

    return true;
  }

  BookTreeNode? findNodeForPage(int pageIndex) {
    if (!containsPage(pageIndex)) {
      return null;
    }

    for (final child in children) {
      final result = child.findNodeForPage(pageIndex);

      if (result != null) {
        return result;
      }
    }

    return this;
  }

  int? resolvePdfPageIndex() {
    if (pageStart == null) {
      return null;
    }

    return pageStart! - 1;
  }
}
