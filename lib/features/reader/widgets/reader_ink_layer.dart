import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ReaderInkTool { pen, highlighter, eraser }

class ReaderInkLayer extends StatefulWidget {
  final List<List<Offset>> strokes;
  final ValueChanged<List<Offset>> onStrokeEnd;
  final bool enabled;
  final Color color;
  final double width;

  const ReaderInkLayer({
    super.key,
    required this.strokes,
    required this.onStrokeEnd,
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
  final List<List<Offset>> _localErased = [];

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
      final hit = _findHit(stroke.last);
      if (hit != null) {
        setState(() => _localErased.add(hit));
        // The reserved first two points are an erase command. The reader page
        // consumes it instead of creating another ink annotation.
        widget.onStrokeEnd([const Offset(0, 0), const Offset(0, 1), ...hit]);
      }
      return;
    }
    widget.onStrokeEnd(stroke);
  }

  List<Offset>? _findHit(Offset p) {
    const tolerance = 22.0;
    for (final stroke in widget.strokes.reversed) {
      for (var i = 0; i < stroke.length; i++) {
        if ((stroke[i] - p).distance <= tolerance) return stroke;
        if (i > 0 && _segmentDistance(p, stroke[i - 1], stroke[i]) <= tolerance) return stroke;
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
    final visible = widget.strokes.where((stroke) => !_localErased.any((erased) => _sameStroke(erased, stroke))).toList();
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
            painter: _ReaderInkPainter(
              strokes: [...visible, if (_current.isNotEmpty) _current],
              color: _tool == ReaderInkTool.highlighter ? Colors.yellow : widget.color,
              width: _tool == ReaderInkTool.highlighter ? widget.width * 4 : widget.width,
              opacity: _tool == ReaderInkTool.highlighter ? .32 : 1,
            ),
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
  final List<List<Offset>> strokes;
  final Color color;
  final double width;
  final double opacity;

  const _ReaderInkPainter({required this.strokes, required this.color, required this.width, this.opacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = ui.Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        final p = stroke[i];
        final previous = stroke[i - 1];
        final midpoint = Offset((previous.dx + p.dx) / 2, (previous.dy + p.dy) / 2);
        path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReaderInkPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.color != color || oldDelegate.width != width || oldDelegate.opacity != opacity;
}
