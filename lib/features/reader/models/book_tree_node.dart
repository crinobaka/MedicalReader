class BookTreeNode {
  final String id;

  final String name;

  /// 1-based PDF page number.
  ///
  /// 例如：
  /// pageStart = 100
  /// 表示这个章节从 PDF 第 100 页开始。
  final int? pageStart;

  /// 1-based PDF page number.
  final int? pageEnd;

  final List<BookTreeNode> children;

  const BookTreeNode({
    required this.id,
    required this.name,
    this.pageStart,
    this.pageEnd,
    this.children = const [],
  });

  factory BookTreeNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];

    final children = <BookTreeNode>[];

    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is Map) {
          children.add(
            BookTreeNode.fromJson(
              Map<String, dynamic>.from(child),
            ),
          );
        }
      }
    }

    return BookTreeNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pageStart: _readInt(json['page_start']),
      pageEnd: _readInt(json['page_end']),
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
}