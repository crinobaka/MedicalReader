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
  final ValueNotifier<Offset>? externalDragDelta;
  final ValueNotifier<int>? externalDragEnd;

  const ReaderRadialToc({
    super.key,
    required this.nodes,
    required this.fromLeft,
    required this.currentPage,
    required this.onSelected,
    required this.onDismiss,
    this.externalDragDelta,
    this.externalDragEnd,
  });

  @override
  State<ReaderRadialToc> createState() => _ReaderRadialTocState();
}

class _ReaderRadialTocState extends State<ReaderRadialToc> {
  static const int _maxDepth = 4;
  static const int _visibleSlots = 9;
  static const double _itemStep = 48.0;
  static const double _enterThreshold = 40.0;
  static const double _exitThreshold = 25.0;

  late List<BookTreeNode> _nodes;
  final List<_TocLevel> _history = [];
  int _index = 0;
  double _verticalRemainder = 0;
  double _horizontalTravel = 0;
  Offset _lastExternalDragDelta = Offset.zero;
  int _lastExternalDragEnd = 0;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _nodes = widget.nodes;
    _index = _closestIndex(_nodes, widget.currentPage);
    _lastExternalDragDelta = widget.externalDragDelta?.value ?? Offset.zero;
    _lastExternalDragEnd = widget.externalDragEnd?.value ?? 0;
    widget.externalDragDelta?.addListener(_onExternalDragDelta);
    widget.externalDragEnd?.addListener(_onExternalDragEnd);
    if (_lastExternalDragDelta != Offset.zero) {
      _applyPanDelta(_lastExternalDragDelta);
    }
  }

  @override
  void didUpdateWidget(covariant ReaderRadialToc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalDragDelta != widget.externalDragDelta) {
      oldWidget.externalDragDelta?.removeListener(_onExternalDragDelta);
      _lastExternalDragDelta = widget.externalDragDelta?.value ?? Offset.zero;
      widget.externalDragDelta?.addListener(_onExternalDragDelta);
    }
    if (oldWidget.externalDragEnd != widget.externalDragEnd) {
      oldWidget.externalDragEnd?.removeListener(_onExternalDragEnd);
      _lastExternalDragEnd = widget.externalDragEnd?.value ?? 0;
      widget.externalDragEnd?.addListener(_onExternalDragEnd);
    }
  }

  @override
  void dispose() {
    widget.externalDragDelta?.removeListener(_onExternalDragDelta);
    widget.externalDragEnd?.removeListener(_onExternalDragEnd);
    super.dispose();
  }

  void _onExternalDragDelta() {
    final value = widget.externalDragDelta?.value ?? Offset.zero;
    final delta = value - _lastExternalDragDelta;
    _lastExternalDragDelta = value;
    if (delta != Offset.zero) _applyPanDelta(delta);
  }

  void _onExternalDragEnd() {
    final value = widget.externalDragEnd?.value ?? 0;
    if (value == _lastExternalDragEnd) return;
    _lastExternalDragEnd = value;
    _handleEnd();
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
    while (_verticalRemainder.abs() >= _itemStep) {
      final direction = _verticalRemainder > 0 ? 1 : -1;
      _index = (_index + direction).clamp(0, _nodes.length - 1);
      _verticalRemainder -= direction * _itemStep;
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
      _horizontalTravel -= _enterThreshold;
      _verticalRemainder = 0;
      setState(() {});
      return;
    }

    if (_horizontalTravel <= -_enterThreshold && _history.isNotEmpty) {
      final prev = _history.removeLast();
      _nodes = prev.nodes;
      _index = prev.index.clamp(0, _nodes.length - 1);
      _horizontalTravel += _enterThreshold;
      _verticalRemainder = 0;
      setState(() {});
    }
  }

  void _applyPanDelta(Offset delta) {
    if (_nodes.isEmpty) return;
    _moveSelection(delta.dy);
    _moveDepth(delta.dx);
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
    final maxRadius = math.min(
      size.width * 0.35,
      (size.height - safeTop - safeBottom) * 0.30,
    );
    final radius = math.max(70.0, maxRadius);
    final centerX = widget.fromLeft ? 0.0 : size.width;
    final centerY = size.height / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onPanUpdate: (details) => _applyPanDelta(details.delta),
      onPanEnd: (_) => _handleEnd(),
      child: CustomPaint(
        size: size,
        painter: _RevolverPainter(
          nodes: _nodes,
          selectedIndex: _index,
          radius: radius,
          center: Offset(centerX, centerY),
          fromLeft: widget.fromLeft,
          verticalRemainder: _verticalRemainder,
          itemStep: _itemStep,
          visibleSlots: _visibleSlots,
          accent: Theme.of(context).colorScheme.primary,
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
  final double verticalRemainder;
  final double itemStep;
  final int visibleSlots;
  final Color accent;

  const _RevolverPainter({
    required this.nodes,
    required this.selectedIndex,
    required this.radius,
    required this.center,
    required this.fromLeft,
    required this.verticalRemainder,
    required this.itemStep,
    required this.visibleSlots,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = nodes.length;
    if (count == 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
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

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = accent.withOpacity(0.25)
      ..strokeWidth = 1.5;
    canvas.drawArc(rect, -math.pi / 2, math.pi, false, strokePaint);

    final slots = math.min(visibleSlots, count);
    final halfSlots = (slots - 1) / 2.0;
    final selectedSlot = math.min(halfSlots, math.min(selectedIndex.toDouble(), count - 1 - selectedIndex));
    final firstIndex = (selectedIndex - halfSlots).round().clamp(0, math.max(0, count - slots));
    final lastIndex = firstIndex + slots - 1;
    final angleSpan = math.pi * 0.78;
    final angleStep = slots > 1 ? angleSpan / (slots - 1) : 0.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = firstIndex; i <= lastIndex; i++) {
      final slot = i - firstIndex;
      final selectedSlotIndex = selectedIndex - firstIndex;
      final angle = -angleSpan / 2 + slot * angleStep;
      final slotOffset = slot - selectedSlotIndex;
      final angleWithDrag = angle + (verticalRemainder / itemStep) * angleStep;
      final x = center.dx + (fromLeft ? 1 : -1) * math.cos(angleWithDrag) * radius;
      final y = center.dy + math.sin(angleWithDrag) * radius;
      final position = Offset(x, y);

      final isSelected = i == selectedIndex;
      final distance = slotOffset.abs().toDouble();
      final opacity = isSelected ? 1.0 : (1.0 - distance / (halfSlots + 1) * 0.45).clamp(0.28, 1.0);

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

      final textStyle = TextStyle(
        color: isSelected ? accent : Colors.black.withOpacity(opacity),
        fontSize: isSelected ? 16 : 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      );
      textPainter.text = TextSpan(text: nodes[i].name, style: textStyle);
      textPainter.layout(maxWidth: radius * 0.72);
      final textOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);

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
        arrowPainter.paint(
          canvas,
          Offset(
            position.dx + textPainter.width / 2 + 2,
            position.dy - arrowPainter.height / 2,
          ),
        );
      }
    }

    if (count > slots) {
      final tipPaint = Paint()
        ..color = accent.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      if (firstIndex > 0) {
        canvas.drawCircle(
          Offset(center.dx + (fromLeft ? radius * 0.35 : -radius * 0.35), center.dy - radius * 0.9),
          4,
          tipPaint,
        );
      }
      if (lastIndex < count - 1) {
        canvas.drawCircle(
          Offset(center.dx + (fromLeft ? radius * 0.35 : -radius * 0.35), center.dy + radius * 0.9),
          4,
          tipPaint,
        );
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