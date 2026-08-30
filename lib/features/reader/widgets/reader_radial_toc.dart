import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

/// Edge-swiped, radial table-of-contents navigator for touch devices.
///
/// The first horizontal swipe opens the navigator. Vertical movement chooses
/// the current level; swiping further inward enters children and swiping back
/// exits the level. Releasing commits the selected entry.
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
  late List<BookTreeNode> _nodes;
  final List<List<BookTreeNode>> _levels = [];
  int _index = 0;
  double _dy = 0;
  double _inward = 0;

  @override
  void initState() {
    super.initState();
    _nodes = widget.nodes;
    if (_nodes.isNotEmpty) _index = _closestIndex(_nodes);
  }

  int _closestIndex(List<BookTreeNode> nodes) {
    if (widget.currentPage == null || nodes.isEmpty) return 0;
    final page = widget.currentPage!;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      final start = nodes[i].resolvePdfPageIndex();
      if (start == null) continue;
      final d = (start - page).abs().toDouble();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  void _moveVertical(double delta) {
    if (_nodes.isEmpty) return;
    _dy += delta;
    const step = 42.0;
    while (_dy.abs() >= step) {
      final direction = _dy > 0 ? 1 : -1;
      _index = (_index + direction).clamp(0, _nodes.length - 1);
      _dy -= direction * step;
    }
    setState(() {});
  }

  void _moveHorizontal(double delta) {
    _inward += widget.fromLeft ? delta : -delta;
    if (_inward > 72 && _nodes.isNotEmpty) {
      final selected = _nodes[_index];
      if (selected.children.isNotEmpty) {
        _levels.add(_nodes);
        _nodes = selected.children;
        _index = _closestIndex(_nodes);
        _inward = 0;
        setState(() {});
      }
    } else if (_inward < -72 && _levels.isNotEmpty) {
      _nodes = _levels.removeLast();
      _index = _closestIndex(_nodes);
      _inward = 0;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) return const SizedBox.shrink();
    final selected = _nodes[_index];
    final size = MediaQuery.sizeOf(context);
    final radius = math.min(size.width * .82, size.height * .44);
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => _moveVertical(details.delta.dy),
        onHorizontalDragUpdate: (details) => _moveHorizontal(details.delta.dx),
        onVerticalDragEnd: (_) => widget.onSelected(selected),
        onHorizontalDragEnd: (_) => widget.onSelected(selected),
        child: ColoredBox(
          color: colorScheme.scrim.withValues(alpha: .24),
          child: Stack(
            children: [
              Positioned(
                left: widget.fromLeft ? 0 : null,
                right: widget.fromLeft ? null : 0,
                top: (size.height - radius) / 2,
                width: radius,
                height: radius,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: .96),
                      borderRadius: BorderRadius.horizontal(
                        left: widget.fromLeft ? Radius.zero : Radius.circular(radius),
                        right: widget.fromLeft ? Radius.circular(radius) : Radius.zero,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: radius * .78,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _levels.isEmpty ? '目录' : '‹ 目录 · ${_levels.length + 1}级',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              selected.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selected.pageLabel.isEmpty ? '上下滑选择 · 向内滑进入' : 'P ${selected.pageLabel}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (selected.children.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: widget.fromLeft ? 16 : null,
                right: widget.fromLeft ? null : 16,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
