import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book_tree_node.dart';

/// Touch-first directory navigator.
///
/// The directory is a side-mounted curved sheet rather than a conventional
/// drawer. Vertical travel selects an entry, inward travel enters children,
/// reverse travel returns/cancels, and release commits the highlighted entry.
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
  static const _rowHeight = 46.0;
  static const _enterThreshold = 58.0;
  static const _commitThreshold = 28.0;

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
    if (_horizontalTravel >= _enterThreshold &&
        _nodes[_index].children.isNotEmpty &&
        _history.length < _maxDepth - 1) {
      final selectedIndex = _index;
      _history.add(_TocLevel(nodes: _nodes, index: selectedIndex));
      _nodes = _nodes[selectedIndex].children;
      _index = _closestIndex(_nodes, widget.currentPage);
      _horizontalTravel = 0;
      _verticalRemainder = 0;
      setState(() {});
      return;
    }
    if (_horizontalTravel <= -_enterThreshold && _history.isNotEmpty) {
      final previous = _history.removeLast();
      _nodes = previous.nodes;
      _index = previous.index.clamp(0, _nodes.length - 1);
      _horizontalTravel = 0;
      _verticalRemainder = 0;
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
    final outward = widget.fromLeft ? _horizontalTravel : -_horizontalTravel;
    if (outward < -_commitThreshold && _history.isEmpty) {
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
    final scheme = Theme.of(context).colorScheme;
    final panelWidth = math.min(380.0, size.width * .82);
    final radius = math.max(72.0, math.min(size.height * .28, panelWidth * .72));
    final selected = _nodes[_index];
    final level = _history.length + 1;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: ColoredBox(color: Colors.black.withValues(alpha: .10)),
            ),
          ),
          Positioned(
            top: safeTop + 8,
            bottom: safeBottom + 8,
            left: widget.fromLeft ? 0 : null,
            right: widget.fromLeft ? null : 0,
            width: panelWidth,
            child: Material(
              color: scheme.surface.withValues(alpha: .98),
              elevation: 10,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: widget.fromLeft ? Radius.zero : Radius.circular(radius),
                  bottomLeft: widget.fromLeft ? Radius.zero : Radius.circular(radius),
                  topRight: widget.fromLeft ? Radius.circular(radius) : Radius.zero,
                  bottomRight: widget.fromLeft ? Radius.circular(radius) : Radius.zero,
                ),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) => _moveSelection(details.delta.dy),
                onHorizontalDragUpdate: (details) => _moveDepth(details.delta.dx),
                onVerticalDragEnd: (_) => _handleEnd(),
                onHorizontalDragEnd: (_) => _handleEnd(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(widget.fromLeft ? 24 : 18, 18, widget.fromLeft ? 18 : 24, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(tooltip: '关闭目录', onPressed: widget.onDismiss, icon: const Icon(Icons.close)),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.account_tree_outlined, size: 17, color: scheme.primary),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              selected.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(selected.pageLabel.isEmpty ? '第 ${_index + 1} 项' : 'P ${selected.pageLabel}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _ArcSelectionRail(
                          nodes: _nodes,
                          selectedIndex: _index,
                          fromLeft: widget.fromLeft,
                          rowHeight: _rowHeight,
                          accent: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
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

class _ArcSelectionRail extends StatelessWidget {
  final List<BookTreeNode> nodes;
  final int selectedIndex;
  final bool fromLeft;
  final double rowHeight;
  final Color accent;

  const _ArcSelectionRail({required this.nodes, required this.selectedIndex, required this.fromLeft, required this.rowHeight, required this.accent});

  @override
  Widget build(BuildContext context) {
    final start = math.max(0, selectedIndex - 3);
    final end = math.min(nodes.length, start + 7);
    final visible = [for (var i = start; i < end; i++) i];
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight / 2;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ArcGuidePainter(fromLeft: fromLeft, color: accent.withValues(alpha: .10), radius: math.max(150.0, constraints.maxHeight * .72))),
            for (var position = 0; position < visible.length; position++)
              _arcItem(context, index: visible[position], position: position, count: visible.length, centerY: centerY),
          ],
        );
      },
    );
  }

  Widget _arcItem(BuildContext context, {required int index, required int position, required int count, required double centerY}) {
    final selected = index == selectedIndex;
    final relative = position - (count - 1) / 2;
    final y = centerY + relative * rowHeight;
    final normalized = (relative / math.max(1, (count - 1) / 2)).abs().clamp(0.0, 1.0);
    final inset = math.pow(normalized, 1.7).toDouble() * 42;
    final width = math.min(270.0, MediaQuery.sizeOf(context).width * .58);
    return Positioned(
      left: fromLeft ? inset : null,
      right: fromLeft ? null : inset,
      top: y - rowHeight / 2,
      width: width,
      height: rowHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .14) : Colors.transparent,
          borderRadius: BorderRadius.circular(rowHeight / 2),
          border: selected ? Border.all(color: accent.withValues(alpha: .48)) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          textDirection: fromLeft ? TextDirection.ltr : TextDirection.rtl,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: selected ? accent : accent.withValues(alpha: .12),
              foregroundColor: selected ? Theme.of(context).colorScheme.onPrimary : accent,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(nodes[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: fromLeft ? TextAlign.left : TextAlign.right, style: selected ? const TextStyle(fontWeight: FontWeight.w700) : null),
            ),
            if (nodes[index].children.isNotEmpty) Icon(fromLeft ? Icons.chevron_right : Icons.chevron_left, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ArcGuidePainter extends CustomPainter {
  final bool fromLeft;
  final Color color;
  final double radius;
  const _ArcGuidePainter({required this.fromLeft, required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(fromLeft ? -radius * .62 : size.width + radius * .62, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final start = fromLeft ? -math.pi * .34 : math.pi * .66;
    canvas.drawArc(rect, start, math.pi * .68, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcGuidePainter oldDelegate) => oldDelegate.fromLeft != fromLeft || oldDelegate.color != color || oldDelegate.radius != radius;
}
