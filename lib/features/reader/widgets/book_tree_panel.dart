import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

class BookTreePanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
        ...nodes.map(
          (node) => _BookTreeNodeTile(
            node: node,
            level: 0,
            currentPage: currentPage,
            onPageSelected: onPageSelected,
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

  final ValueChanged<int> onPageSelected;

  const _BookTreeNodeTile({
    required this.node,
    required this.level,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;

    final isCurrent = node.containsPage(currentPage);

    final title = node.name.isEmpty ? node.id : node.name;

    final pageText = node.pageStart == null
        ? null
        : node.pageEnd == null
            ? 'P${node.pageStart}'
            : 'P${node.pageStart}-${node.pageEnd}';

    final tile = ListTile(
      dense: level > 1,
      selected: isCurrent,
      contentPadding: EdgeInsets.only(
        left: 16.0 + level * 16.0,
        right: 12,
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: pageText == null ? null : Text(pageText),
      onTap: node.pageStart == null
          ? null
          : () {
              onPageSelected(node.pageStart! - 1);
            },
    );

    if (!hasChildren) {
      return tile;
    }

    return ExpansionTile(
      initiallyExpanded: isCurrent,
      tilePadding: EdgeInsets.only(
        left: 8.0 + level * 16.0,
        right: 12,
      ),
      childrenPadding: EdgeInsets.zero,
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: pageText == null ? null : Text(pageText),
      selected: isCurrent,
      onExpansionChanged: (_) {},
      children: [
        ...node.children.map(
          (child) => _BookTreeNodeTile(
            node: child,
            level: level + 1,
            currentPage: currentPage,
            onPageSelected: onPageSelected,
          ),
        ),
      ],
    );
  }
}