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
    this.tool = ReaderInkTool.pen,
    this.color = Colors.red,
    this.width = 2.6,
    this.opacity = 1,
  });

  ReaderInkStroke copyWith({List<Offset>? points}) => ReaderInkStroke(
        points: points ?? this.points,
        tool: tool,
        color: color,
        width: width,
        opacity: opacity,
      );
}

class ReaderInkLayer extends StatefulWidget {
  final List<ReaderInkStroke> strokes;
  final ValueChanged<ReaderInkStroke> onStrokeEnd;
  final ValueChanged<ReaderInkStroke>? onEraseStroke;
  final bool enabled;
  final Color color;
  final double width;

  const ReaderInkLayer({
    super.key,
    required this.strokes,
    required this.onStrokeEnd,
    this.onEraseStroke,
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
    final stroke = _current;
    setState(() => _current = const []);

    if (_tool == ReaderInkTool.eraser) {
      final hit = _findHit(stroke);
      if (hit != null) {
        setState(() => _localErased.add(hit));
        widget.onEraseStroke?.call(hit);
      }
      return;
    }

    widget.onStrokeEnd(ReaderInkStroke(
      points: stroke,
      tool: _tool,
      color: widget.color,
      width: widget.width,
      opacity: _tool == ReaderInkTool.highlighter ? .28 : 1,
    ));
  }

  ReaderInkStroke? _findHit(List<Offset> eraserPath) {
    const tolerance = 18.0;
    for (final candidate in widget.strokes.reversed) {
      final points = candidate.points;
      for (var i = 1; i < points.length; i++) {
        for (var j = 1; j < eraserPath.length; j++) {
          if (_segmentsIntersectWithin(eraserPath[j - 1], eraserPath[j], points[i - 1], points[i], tolerance)) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  bool _segmentsIntersectWithin(Offset a1, Offset a2, Offset b1, Offset b2, double tolerance) {
    if (_segmentDistance(a1, b1, b2) <= tolerance || _segmentDistance(a2, b1, b2) <= tolerance) return true;
    if (_segmentDistance(b1, a1, a2) <= tolerance || _segmentDistance(b2, a1, a2) <= tolerance) return true;
    return false;
  }

  double _segmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return (p - a).distance;
    final t = ((((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / len2).clamp(0.0, 1.0).toDouble();
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.strokes.where((stroke) => !_localErased.any((erased) => identical(erased, stroke) || _sameStroke(erased, stroke))).toList();
    final rendered = [...visible];
    if (_current.length >= 2 && _tool != ReaderInkTool.eraser) {
      rendered.add(ReaderInkStroke(
        points: _current,
        tool: _tool,
        color: widget.color,
        width: widget.width,
        opacity: _tool == ReaderInkTool.highlighter ? .28 : 1,
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
          child: CustomPaint(painter: _ReaderInkPainter(strokes: rendered), size: Size.infinite),
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
      style: IconButton.styleFrom(backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null),
      icon: Icon(icon),
    );
  }

  bool _sameStroke(ReaderInkStroke a, ReaderInkStroke b) {
    if (a.points.length != b.points.length) return false;
    for (var i = 0; i < a.points.length; i++) {
      if ((a.points[i] - b.points[i]).distance > .5) return false;
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
      final points = stroke.points;
      if (points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = stroke.tool == ReaderInkTool.highlighter ? stroke.width * 3.5 : stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.tool == ReaderInkTool.highlighter) {
        paint.blendMode = BlendMode.multiply;
      }
      final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p = points[i];
        final previous = points[i - 1];
        final midpoint = Offset((previous.dx + p.dx) / 2, (previous.dy + p.dy) / 2);
        path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReaderInkPainter oldDelegate) => oldDelegate.strokes != strokes;
}
