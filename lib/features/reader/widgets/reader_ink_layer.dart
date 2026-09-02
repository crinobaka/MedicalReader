import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ReaderInkTool { pen, highlighter, eraser }

class ReaderInkStroke {
  final List<Offset> points;
  final ReaderInkTool tool;
  final Color color;
  final double width;
  final double opacity;

  const ReaderInkStroke({
    required this.points,
    required this.tool,
    required this.color,
    required this.width,
    this.opacity = 1,
  });
}

class ReaderInkLayer extends StatefulWidget {
  final List<ReaderInkStroke> strokes;
  final ValueChanged<ReaderInkStroke> onStrokeEnd;
  final ValueChanged<ReaderInkStroke>? onErase;
  final bool enabled;
  final Color color;
  final double width;

  const ReaderInkLayer({
    super.key,
    required this.strokes,
    required this.onStrokeEnd,
    this.onErase,
    required this.enabled,
    this.color = Colors.red,
    this.width = 2.6,
  });

  @override
  State<ReaderInkLayer> createState() => _ReaderInkLayerState();
}

class _ReaderInkLayerState extends State<ReaderInkLayer> {
  List<Offset> _current = const [];
  ReaderInkTool _tool = ReaderInkTool.pen;
  final List<ReaderInkStroke> _localErased = [];

  void _start(DragStartDetails details) {
    if (!widget.enabled) return;
    setState(() => _current = [details.localPosition]);
  }

  void _update(DragUpdateDetails details) {
    if (!widget.enabled || _current.isEmpty) return;
    setState(() => _current = [..._current, details.localPosition]);
  }

  void _end(DragEndDetails details) {
    if (!widget.enabled || _current.length < 2) {
      if (mounted) setState(() => _current = const []);
      return;
    }
    final points = _current;
    setState(() => _current = const []);

    if (_tool == ReaderInkTool.eraser) {
      final hit = _findHit(points.last);
      if (hit != null) {
        setState(() => _localErased.add(hit));
        widget.onErase?.call(hit);
      }
      return;
    }

    widget.onStrokeEnd(ReaderInkStroke(
      points: points,
      tool: _tool,
      color: _tool == ReaderInkTool.highlighter ? Colors.yellow : widget.color,
      width: _tool == ReaderInkTool.highlighter ? widget.width * 4 : widget.width,
      opacity: _tool == ReaderInkTool.highlighter ? .32 : 1,
    ));
  }

  ReaderInkStroke? _findHit(Offset p) {
    const tolerance = 22.0;
    for (final stroke in widget.strokes.reversed) {
      for (var i = 0; i < stroke.points.length; i++) {
        if ((stroke.points[i] - p).distance <= tolerance) return stroke;
        if (i > 0 && _segmentDistance(p, stroke.points[i - 1], stroke.points[i]) <= tolerance) return stroke;
      }
    }
    return null;
  }

  double _segmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / len2;
    final u = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + u * dx, a.dy + u * dy)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.strokes.where((stroke) => !_localErased.any((erased) => _sameStroke(erased.points, stroke.points))).toList();
    final rendered = [...visible];
    if (_current.length >= 2 && _tool != ReaderInkTool.eraser) {
      rendered.add(ReaderInkStroke(
        points: _current,
        tool: _tool,
        color: _tool == ReaderInkTool.highlighter ? Colors.yellow : widget.color,
        width: _tool == ReaderInkTool.highlighter ? widget.width * 4 : widget.width,
        opacity: _tool == ReaderInkTool.highlighter ? .32 : 1,
      ));
    }
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: widget.enabled ? HitTestBehavior.opaque : HitTestBehavior.translucent,
          onPanStart: _start,
          onPanUpdate: _update,
          onPanEnd: _end,
          child: CustomPaint(
            painter: _ReaderInkPainter(strokes: rendered),
            size: Size.infinite,
          ),
        ),
        if (widget.enabled)
          Positioned(
            left: 12,
            bottom: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(18),
              color: scheme.surface.withValues(alpha: .96),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolButton(Icons.edit, '笔', ReaderInkTool.pen),
                    _toolButton(Icons.highlight, '荧光笔', ReaderInkTool.highlighter),
                    _toolButton(Icons.auto_fix_off, '橡皮擦', ReaderInkTool.eraser),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _toolButton(IconData icon, String label, ReaderInkTool tool) {
    final selected = _tool == tool;
    return IconButton(
      tooltip: label,
      onPressed: () => setState(() => _tool = tool),
      style: IconButton.styleFrom(
        backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      icon: Icon(icon),
    );
  }

  bool _sameStroke(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distance > .5) return false;
    }
    return true;
  }
}

class _ReaderInkPainter extends CustomPainter {
  final List<ReaderInkStroke> strokes;

  const _ReaderInkPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = ui.Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        final previous = stroke.points[i - 1];
        final midpoint = Offset((previous.dx + p.dx) / 2, (previous.dy + p.dy) / 2);
        path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReaderInkPainter oldDelegate) => oldDelegate.strokes != strokes;
}
