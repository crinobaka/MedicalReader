import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

class BookTreePanel extends StatefulWidget {
  final List<BookTreeNode> nodes;

  final int currentPage;

  final ValueChanged<int> onPageSelected;

  const BookTreePanel({
    super.key,
    required this.nodes,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  State<BookTreePanel> createState() => _BookTreePanelState();
}

class _BookTreePanelState extends State<BookTreePanel> {
  final Set<String> _expandedNodes = <String>{};

  @override
  void initState() {
    super.initState();
    _syncExpandedNodes();
  }

  @override
  void didUpdateWidget(covariant BookTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPage != widget.currentPage ||
        oldWidget.nodes != widget.nodes) {
      _syncExpandedNodes();
    }
  }

  void _syncExpandedNodes() {
    final currentPath = <String>[];

    for (final node in widget.nodes) {
      if (_collectCurrentPath(node, widget.currentPage, currentPath)) {
        break;
      }
    }

    if (currentPath.isEmpty) {
      return;
    }

    setState(() {
      _expandedNodes.addAll(currentPath);
    });
  }

  bool _collectCurrentPath(
    BookTreeNode node,
    int pageIndex,
    List<String> path,
  ) {
    if (!node.containsPage(pageIndex)) {
      return false;
    }

    path.add(node.id);

    for (final child in node.children) {
      final childPath = <String>[];

      if (_collectCurrentPath(child, pageIndex, childPath)) {
        path.addAll(childPath);
        return true;
      }
    }

    return true;
  }

  void _toggleNode(BookTreeNode node, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedNodes.add(node.id);
      } else {
        _expandedNodes.remove(node.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '暂无目录\n\n当前书籍没有加载 BookTree 索引。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '目录',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        ...widget.nodes.map(
          (node) => _BookTreeNodeTile(
            node: node,
            level: 0,
            currentPage: widget.currentPage,
            expandedNodes: _expandedNodes,
            onExpansionChanged: _toggleNode,
            onPageSelected: widget.onPageSelected,
          ),
        ),
      ],
    );
  }
}

class _BookTreeNodeTile extends StatelessWidget {
  final BookTreeNode node;

  final int level;

  final int currentPage;

  final Set<String> expandedNodes;

  final void Function(BookTreeNode node, bool expanded) onExpansionChanged;

  final ValueChanged<int> onPageSelected;

  const _BookTreeNodeTile({
    required this.node,
    required this.level,
    required this.currentPage,
    required this.expandedNodes,
    required this.onExpansionChanged,
    required this.onPageSelected,
  });

  String? _pageText() {
    final bookStart = node.bookPageStart;
    final bookEnd = node.bookPageEnd;

    final pdfStart = node.pageStart;
    final pdfEnd = node.pageEnd;

    if (bookStart != null) {
      final bookText = bookEnd == null
          ? '书籍 P$bookStart'
          : '书籍 P$bookStart-$bookEnd';

      if (pdfStart == null) {
        return bookText;
      }

      final pdfText = pdfEnd == null
          ? 'PDF P$pdfStart'
          : 'PDF P$pdfStart-$pdfEnd';

      return '$bookText · $pdfText';
    }

    if (pdfStart == null) {
      return null;
    }

    return pdfEnd == null ? 'PDF P$pdfStart' : 'PDF P$pdfStart-$pdfEnd';
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;

    final isCurrent = node.containsPage(currentPage);

    final title = node.name.isEmpty ? node.id : node.name;

    final pageText = _pageText();

    if (!hasChildren) {
      return ListTile(
        dense: level > 1,
        selected: isCurrent,
        contentPadding: EdgeInsets.only(left: 16.0 + level * 16.0, right: 12),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: pageText == null ? null : Text(pageText),
        onTap: () {
          final pageIndex = node.resolvePdfPageIndex();

          if (pageIndex == null) {
            return;
          }

          onPageSelected(pageIndex);
        },
      );
    }

    return ExpansionTile(
      key: PageStorageKey<String>(node.id),
      initiallyExpanded: expandedNodes.contains(node.id),
      tilePadding: EdgeInsets.only(left: 8.0 + level * 16.0, right: 12),
      childrenPadding: EdgeInsets.zero,
      title: Container(
        decoration: isCurrent
            ? BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: isCurrent
              ? TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
      ),
      subtitle: pageText == null ? null : Text(pageText),
      onExpansionChanged: (expanded) {
        onExpansionChanged(node, expanded);
      },
      onTap: () {
        final pageIndex = node.resolvePdfPageIndex();

        if (pageIndex == null) {
          return;
        }

        onPageSelected(pageIndex);
      },
      children: [
        ...node.children.map(
          (child) => _BookTreeNodeTile(
            node: child,
            level: level + 1,
            currentPage: currentPage,
            expandedNodes: expandedNodes,
            onExpansionChanged: onExpansionChanged,
            onPageSelected: onPageSelected,
          ),
        ),
      ],
    );
  }
}
