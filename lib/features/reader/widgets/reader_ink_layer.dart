import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
    widget.onStrokeEnd(stroke);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.enabled ? HitTestBehavior.opaque : HitTestBehavior.translucent,
      onPanStart: _start,
      onPanUpdate: _update,
      onPanEnd: _end,
      child: CustomPaint(
        painter: _ReaderInkPainter(
          strokes: [...widget.strokes, if (_current.isNotEmpty) _current],
          color: widget.color,
          width: widget.width,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ReaderInkPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  const _ReaderInkPainter({required this.strokes, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
      oldDelegate.strokes != strokes || oldDelegate.color != color || oldDelegate.width != width;
}
