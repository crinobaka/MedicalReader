import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

/// Touch-first radial TOC navigator.
///
/// The navigator intentionally owns only the navigation gesture. It does not
/// consume the whole reader surface: only the radial sheet and its handle are
/// interactive, so an accidental drag outside the sheet still belongs to the
/// reader (for example page navigation).
class ReaderRadialToc extends StatefulWidget {
  final List<BookTreeNode> nodes;
  final bool fromLeft;
  final int? currentPage;
  final ValueChanged<BookTreeNode> onSelected;
  final VoidCallback onDismiss;

  const ReaderRadialToc({
    super.key,
    required this.nodes,
    required this.fromLeft,
    required this.currentPage,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<ReaderRadialToc> createState() => _ReaderRadialTocState();
}

class _ReaderRadialTocState extends State<ReaderRadialToc> {
  static const _maxDepth = 3;
  static const _rowHeight = 44.0;
  static const _enterThreshold = 64.0;
  static const _commitThreshold = 34.0;

  late List<BookTreeNode> _nodes;
  final List<_TocLevel> _history = [];
  int _index = 0;
  double _verticalRemainder = 0;
  double _horizontalTravel = 0;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _nodes = widget.nodes;
    _index = _closestIndex(_nodes, widget.currentPage);
  }

  int _closestIndex(List<BookTreeNode> nodes, int? page) {
    if (nodes.isEmpty || page == null) return 0;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      final candidate = nodes[i].resolvePdfPageIndex();
      if (candidate == null) continue;
      final nextDistance = (candidate - page).abs().toDouble();
      if (nextDistance < distance) {
        distance = nextDistance;
        best = i;
      }
    }
    return best;
  }

  void _moveSelection(double delta) {
    if (_nodes.length < 2) return;
    _verticalRemainder += delta;
    while (_verticalRemainder.abs() >= _rowHeight) {
      final direction = _verticalRemainder > 0 ? 1 : -1;
      _index = (_index + direction).clamp(0, _nodes.length - 1);
      _verticalRemainder -= direction * _rowHeight;
    }
    setState(() {});
  }

  void _moveDepth(double delta) {
    final inwardDelta = widget.fromLeft ? delta : -delta;
    _horizontalTravel += inwardDelta;

    if (_horizontalTravel >= _enterThreshold && _nodes[_index].children.isNotEmpty && _history.length < _maxDepth - 1) {
      _history.add(_TocLevel(nodes: _nodes, index: _index));
      _nodes = _nodes[_index].children;
      _index = _closestIndex(_nodes, widget.currentPage);
      _horizontalTravel = 0;
      setState(() {});
      return;
    }

    if (_horizontalTravel <= -_enterThreshold && _history.isNotEmpty) {
      final previous = _history.removeLast();
      _nodes = previous.nodes;
      _index = previous.index.clamp(0, _nodes.length - 1);
      _horizontalTravel = 0;
      setState(() {});
    }
  }

  void _commit() {
    if (_committed || _nodes.isEmpty) return;
    _committed = true;
    widget.onSelected(_nodes[_index]);
  }

  void _handleEnd() {
    if (_committed) return;
    final inward = widget.fromLeft ? _horizontalTravel : -_horizontalTravel;
    // A reverse gesture is navigation within the hierarchy, not a jump.
    if (inward < -_commitThreshold && _history.isEmpty) {
      widget.onDismiss();
      return;
    }
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final panelRadius = math.min(size.width * .88, size.height * .76);
    final panelWidth = math.min(size.width * .86, panelRadius);
    final scheme = Theme.of(context).colorScheme;
    final selected = _nodes[_index];
    final level = _history.length + 1;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: safeTop + 12,
            bottom: safeBottom + 12,
            left: widget.fromLeft ? 0 : null,
            right: widget.fromLeft ? null : 0,
            width: panelWidth,
            child: Material(
              color: scheme.surface.withValues(alpha: .97),
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.horizontal(
                left: widget.fromLeft ? Radius.zero : Radius.circular(panelRadius),
                right: widget.fromLeft ? Radius.circular(panelRadius) : Radius.zero,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) => _moveSelection(details.delta.dy),
                onHorizontalDragUpdate: (details) => _moveDepth(details.delta.dx),
                onVerticalDragEnd: (_) => _handleEnd(),
                onHorizontalDragEnd: (_) => _handleEnd(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.fromLeft ? 28 : 20,
                    22,
                    widget.fromLeft ? 20 : 28,
                    22,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: '关闭目录',
                            onPressed: widget.onDismiss,
                            icon: const Icon(Icons.close),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              level == 1 ? '目录' : '目录 · $level级',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text('${_index + 1}/${_nodes.length}', style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          selected.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected.pageLabel.isEmpty ? '第 ${_index + 1} 项' : 'P ${selected.pageLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Center(
                          child: _TocRail(
                            nodes: _nodes,
                            selectedIndex: _index,
                            rowHeight: _rowHeight,
                            accent: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selected.children.isNotEmpty && level < _maxDepth
                            ? '上下滑选择 · 向内滑进入 · 反向滑返回'
                            : _history.isNotEmpty
                                ? '上下滑选择 · 反向滑返回 · 松手跳转'
                                : '上下滑选择 · 松手跳转 · 反向滑动取消',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TocLevel {
  final List<BookTreeNode> nodes;
  final int index;

  const _TocLevel({required this.nodes, required this.index});
}

class _TocRail extends StatelessWidget {
  final List<BookTreeNode> nodes;
  final int selectedIndex;
  final double rowHeight;
  final Color accent;

  const _TocRail({
    required this.nodes,
    required this.selectedIndex,
    required this.rowHeight,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final start = math.max(0, selectedIndex - 2);
    final end = math.min(nodes.length, start + 5);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = start; i < end; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: rowHeight,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: i == selectedIndex ? accent.withValues(alpha: .12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: i == selectedIndex ? Border.all(color: accent.withValues(alpha: .42)) : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text('${i + 1}', textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nodes[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: i == selectedIndex ? const TextStyle(fontWeight: FontWeight.w700) : null,
                  ),
                ),
                if (nodes[i].children.isNotEmpty) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
