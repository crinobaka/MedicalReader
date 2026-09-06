class ReaderOutlineItem {
  final String id;
  final String title;
  final ReaderOutlineTarget target;
  final List<ReaderOutlineItem> children;

  const ReaderOutlineItem({
    required this.id,
    required this.title,
    required this.target,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
}

sealed class ReaderOutlineTarget {
  const ReaderOutlineTarget();
}

final class PdfOutlineTarget extends ReaderOutlineTarget {
  final int pageIndex;

  const PdfOutlineTarget(this.pageIndex);
}

final class EpubOutlineTarget extends ReaderOutlineTarget {
  final String href;
  final String? fragment;

  const EpubOutlineTarget({
    required this.href,
    this.fragment,
  });
}
