import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ReaderInkTool { pen, highlighter, eraser }

class ReaderInkLayer extends StatefulWidget {
  final List<List<Offset>> strokes;
  final ValueChanged<List<Offset>> onStrokeEnd;
  final bool enabled;
  final Color color;
  final double width;

  const ReaderInkLayer({super.key, required this.strokes, required this.onStrokeEnd, required this.enabled, this.color = Colors.red, this.width = 2.6});

  @override
  State<ReaderInkLayer> createState() => _ReaderInkLayerState();
}

class _ReaderInkLayerState extends State<ReaderInkLayer> {
  List<Offset> _current = const [];
  ReaderInkTool _tool = ReaderInkTool.pen;
  final List<List<Offset>> _localErased = [];

  void _start(DragStartDetails details) { if (!widget.enabled) return; setState(() => _current = [details.localPosition]); }
  void _update(DragUpdateDetails details) { if (!widget.enabled || _current.isEmpty) return; setState(() => _current = [..._current, details.localPosition]); }

  void _end(DragEndDetails details) {
    if (!widget.enabled || _current.length < 2) { if (mounted) setState(() => _current = const []); return; }
    final stroke = _current;
    setState(() => _current = const []);
    if (_tool == ReaderInkTool.eraser) {
      final hit = _findHit(stroke.last);
      if (hit != null) {
        setState(() => _localErased.add(hit));
        widget.onStrokeEnd([const Offset(0, 0), const Offset(0, 1), ..._stripMetadata(hit)]);
      }
      return;
    }
    widget.onStrokeEnd(_withMetadata(stroke));
  }

  List<Offset> _withMetadata(List<Offset> points) => [
        Offset(-1, _tool.index.toDouble()),
        Offset(-2, widget.color.value.toDouble() / 0xffffffff.toDouble()),
        Offset(-3, widget.width / 1000),
        Offset(-4, _tool == ReaderInkTool.highlighter ? .32 : 1),
        ...points,
      ];

  List<Offset> _stripMetadata(List<Offset> stroke) => stroke.length >= 4 && stroke.first.dx < 0 ? stroke.sublist(4) : stroke;

  List<Offset>? _findHit(Offset p) {
    const tolerance = 22.0;
    for (final stroke in widget.strokes.reversed) {
      final points = _stripMetadata(stroke);
      for (var i = 0; i < points.length; i++) {
        if ((points[i] - p).distance <= tolerance) return stroke;
        if (i > 0 && _segmentDistance(p, points[i - 1], points[i]) <= tolerance) return stroke;
      }
    }
    return null;
  }

  double _segmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy, len2 = dx * dx + dy * dy;
    if (len2 == 0) return (p - a).distance;
    final t = ((((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / len2).clamp(0.0, 1.0).toDouble();
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.strokes.where((stroke) => !_localErased.any((erased) => _sameStroke(erased, stroke))).toList();
    final rendered = [...visible];
    if (_current.length >= 2 && _tool != ReaderInkTool.eraser) rendered.add(_withMetadata(_current));
    final scheme = Theme.of(context).colorScheme;
    return Stack(fit: StackFit.expand, children: [
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
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _toolButton(Icons.edit, '笔', ReaderInkTool.pen),
                _toolButton(Icons.highlight, '荧光笔', ReaderInkTool.highlighter),
                _toolButton(Icons.auto_fix_off, '橡皮擦', ReaderInkTool.eraser),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _toolButton(IconData icon, String label, ReaderInkTool tool) {
    final selected = _tool == tool;
    return IconButton(tooltip: label, onPressed: () => setState(() => _tool = tool), style: IconButton.styleFrom(backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null), icon: Icon(icon));
  }

  bool _sameStroke(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) { if ((a[i] - b[i]).distance > .5) return false; }
    return true;
  }
}

class _ReaderInkPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _ReaderInkPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final encoded in strokes) {
      if (encoded.length < 2) continue;
      var tool = ReaderInkTool.pen;
      var color = Colors.red;
      var width = 2.6;
      var opacity = 1.0;
      var start = 0;
      if (encoded.length >= 5 && encoded.first.dx < 0) {
        final toolIndex = encoded[0].y.round().clamp(0, ReaderInkTool.values.length - 1).toInt();
        tool = ReaderInkTool.values[toolIndex];
        final colorValue = (encoded[1].y.clamp(0.0, 1.0) * 0xffffffff.toDouble()).round();
        color = Color(colorValue);
        width = encoded[2].y.clamp(.001, .05).toDouble() * 1000;
        opacity = encoded[3].y.clamp(.05, 1.0).toDouble();
        start = 4;
      }
      final points = encoded.sublist(start);
      if (points.length < 2) continue;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = tool == ReaderInkTool.highlighter ? width * 1.35 : width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p = points[i], previous = points[i - 1];
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
