import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/book_tree_node.dart';

/// 左轮弹夹式目录导航（垂直条幅排布）
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
  static const int _maxDepth = 4;
  static const double _itemHeight = 46.0;
  static const double _enterThreshold = 40.0;
  static const double _exitThreshold = 25.0;

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
      final d = (candidate - page).abs().toDouble();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  void _moveSelection(double delta) {
    _verticalRemainder += delta;
    while (_verticalRemainder.abs() >= _itemHeight) {
      final direction = _verticalRemainder > 0 ? 1 : -1;
      _index = (_index + direction).clamp(0, _nodes.length - 1);
      _verticalRemainder -= direction * _itemHeight;
    }
    setState(() {});
  }

  void _moveDepth(double delta) {
    final inwardDelta = widget.fromLeft ? delta : -delta;
    _horizontalTravel += inwardDelta;

    if (_horizontalTravel >= _enterThreshold &&
        _nodes[_index].children.isNotEmpty &&
        _history.length < _maxDepth - 1) {
      final idx = _index;
      _history.add(_TocLevel(nodes: _nodes, index: idx));
      _nodes = _nodes[idx].children;
      _index = _closestIndex(_nodes, widget.currentPage);
      _horizontalTravel = 0;
      _verticalRemainder = 0;
      setState(() {});
      return;
    }

    if (_horizontalTravel <= -_enterThreshold && _history.isNotEmpty) {
      final prev = _history.removeLast();
      _nodes = prev.nodes;
      _index = prev.index.clamp(0, _nodes.length - 1);
      _horizontalTravel = 0;
      _verticalRemainder = 0;
      setState(() {});
      return;
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
    if (outward < -_exitThreshold && _history.isEmpty) {
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

    // 半径：基于宽度，避免太大
    final maxRadius = math.min(
      size.width * 0.35,
      (size.height - safeTop - safeBottom) * 0.30,
    );
    final radius = math.max(70.0, maxRadius);

    final count = _nodes.length;
    // 垂直分布：每个条目占用的垂直步长（弧度对应的高度）
    final verticalStep = count > 1 ? (radius * 1.6) / (count - 1) : 0.0;

    // 圆心位置
    final centerX = widget.fromLeft ? 0.0 : size.width;
    final centerY = size.height / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.transparent,
        child: CustomPaint(
          size: size,
          painter: _RevolverPainter(
            nodes: _nodes,
            selectedIndex: _index,
            radius: radius,
            center: Offset(centerX, centerY),
            fromLeft: widget.fromLeft,
            verticalStep: verticalStep,
            verticalRemainder: _verticalRemainder,
            itemHeight: _itemHeight,
            accent: Theme.of(context).colorScheme.primary,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => _moveSelection(d.delta.dy),
            onHorizontalDragUpdate: (d) => _moveDepth(d.delta.dx),
            onVerticalDragEnd: (_) => _handleEnd(),
            onHorizontalDragEnd: (_) => _handleEnd(),
          ),
        ),
      ),
    );
  }
}

class _TocLevel {
  final List<BookTreeNode> nodes;
  final int index;
  const _TocLevel({required this.nodes, required this.index});
}

class _RevolverPainter extends CustomPainter {
  final List<BookTreeNode> nodes;
  final int selectedIndex;
  final double radius;
  final Offset center;
  final bool fromLeft;
  final double verticalStep;
  final double verticalRemainder;
  final double itemHeight;
  final Color accent;

  const _RevolverPainter({
    required this.nodes,
    required this.selectedIndex,
    required this.radius,
    required this.center,
    required this.fromLeft,
    required this.verticalStep,
    required this.verticalRemainder,
    required this.itemHeight,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = nodes.length;
    if (count == 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. 半透明背景弧
    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.white.withOpacity(0.96),
          Colors.white.withOpacity(0.80),
        ],
        stops: const [0.2, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi, true, bgPaint);

    // 2. 边框
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = accent.withOpacity(0.25)
      ..strokeWidth = 1.5;
    canvas.drawArc(rect, -math.pi / 2, math.pi, false, strokePaint);

    // 3. 计算垂直范围：使得选中项在垂直中心，其他项上下均匀分布
    // 实际垂直偏移量 = (i - selectedIndex) * verticalStep + verticalRemainder
    // 但我们需要让条目水平位置随垂直偏移略微弯曲，形成弧形
    // 我们取水平偏移 = 半径 - sqrt(半径^2 - 垂直偏移^2)  (内弧)
    final halfCount = (count - 1) / 2.0;
    final maxVertical = halfCount * verticalStep; // 最大垂直偏移

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < count; i++) {
      final verticalOffset = (i - selectedIndex) * verticalStep + verticalRemainder;
      // 限制垂直偏移在 -radius 到 radius 之间，避免超出弧线
      final clampedVertical = verticalOffset.clamp(-radius * 0.95, radius * 0.95);

      // 计算水平偏移（弧线弯曲）：根据垂直偏移计算对应的水平缩进
      // 从圆心到弧上的点：x = centerX + 水平偏移, y = centerY + 垂直偏移
      // 但我们要让条目在弧线上，所以水平偏移 = sqrt(radius^2 - verticalOffset^2) * (fromLeft ? 1 : -1)
      final horizontalOffset = math.sqrt(math.max(0, radius * radius - clampedVertical * clampedVertical));
      final posX = center.dx + (fromLeft ? horizontalOffset : -horizontalOffset);
      final posY = center.dy + clampedVertical;

      final position = Offset(posX, posY);

      final isSelected = (i == selectedIndex);
      final distance = (i - selectedIndex).abs().toDouble();
      final maxDist = (count - 1) / 2.0;
      final ratio = maxDist > 0 ? distance / maxDist : 0.0;
      final opacity = isSelected ? 1.0 : (1.0 - ratio * 0.5).clamp(0.2, 1.0);

      // 高亮背景
      if (isSelected) {
        final hlPaint = Paint()
          ..color = accent.withOpacity(0.18)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(position, 20, hlPaint);
        final borderPaint = Paint()
          ..color = accent.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(position, 20, borderPaint);
      }

      // 文本（水平显示）
      final textStyle = TextStyle(
        color: isSelected ? accent : Colors.black.withOpacity(opacity),
        fontSize: isSelected ? 16 : 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      );
      textPainter.text = TextSpan(text: nodes[i].name, style: textStyle);
      textPainter.layout();
      // 文本居中显示在 position 处
      final textOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);

      // 子目录箭头
      if (nodes[i].children.isNotEmpty) {
        final arrowPainter = TextPainter(
          text: TextSpan(
            text: ' ›',
            style: TextStyle(
              color: accent.withOpacity(opacity * 0.6),
              fontSize: 14,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        arrowPainter.layout();
        final arrowOffset = Offset(
          position.dx + textPainter.width / 2 + 2,
          position.dy - arrowPainter.height / 2,
        );
        arrowPainter.paint(canvas, arrowOffset);
      }
    }

    // 4. 上下渐隐指示点（表示还有更多条目）
    if (count > 3) {
      final tipPaint = Paint()
        ..color = accent.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      // 顶部点
      if (selectedIndex > 0) {
        final topY = center.dy - radius * 0.9;
        final topX = center.dx + (fromLeft ? radius * 0.4 : -radius * 0.4);
        canvas.drawCircle(Offset(topX, topY), 4, tipPaint);
      }
      if (selectedIndex < count - 1) {
        final bottomY = center.dy + radius * 0.9;
        final bottomX = center.dx + (fromLeft ? radius * 0.4 : -radius * 0.4);
        canvas.drawCircle(Offset(bottomX, bottomY), 4, tipPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevolverPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.verticalRemainder != verticalRemainder ||
        oldDelegate.nodes != nodes;
  }
}