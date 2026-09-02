import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/reader_ink_stroke.dart';

class ReaderInkLayer extends StatefulWidget {
  final List<List<Offset>> strokes;
  final List<ReaderInkStroke> typedStrokes;
  final ValueChanged<List<Offset>> onStrokeEnd;
  final ValueChanged<ReaderInkStroke>? onStrokeEndData;
  final bool enabled;
  final Color color;
  final double width;

  const ReaderInkLayer({
    super.key,
    required this.strokes,
    this.typedStrokes = const [],
    required this.onStrokeEnd,
    this.onStrokeEndData,
    this.enabled = false,
    this.color = Colors.red,
    this.width = 2.6,
  });

  @override
  State<ReaderInkLayer> createState() => _ReaderInkLayerState();
}

class _ReaderInkLayerState extends State<ReaderInkLayer> {
  List<Offset> _current = const [];
  ReaderInkTool _tool = ReaderInkTool.pen;
  Color _color = Colors.red;
  double _width = 2.6;
  final List<ReaderInkStroke> _localErasedTyped = [];
  final List<List<Offset>> _localErasedLegacy = [];
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _color = widget.color;
    _width = widget.width;
  }

  void _start(DragStartDetails d) {
    if (widget.enabled) setState(() => _current = [d.localPosition]);
  }

  void _update(DragUpdateDetails d) {
    if (widget.enabled && _current.isNotEmpty) {
      setState(() => _current = [..._current, d.localPosition]);
    }
  }

  void _end(DragEndDetails d) {
    if (!widget.enabled || _current.length < 2) {
      if (mounted) setState(() => _current = const []);
      return;
    }
    final stroke = _current;
    setState(() => _current = const []);

    if (_tool == ReaderInkTool.eraser) {
      final typedHit = _hitTyped(stroke);
      if (typedHit != null) {
        setState(() => _localErasedTyped.add(typedHit));
        widget.onStrokeEndData?.(ReaderInkStroke(
          tool: ReaderInkTool.eraser,
          color: _color,
          width: _width,
          opacity: 1,
          points: stroke,
        ));
        if (widget.onStrokeEndData == null) {
          widget.onStrokeEnd([const Offset(0, 0), const Offset(0, 1), ..._strip(typedHit.points)]);
        }
        return;
      }
      final legacyHit = _hitLegacy(stroke);
      if (legacyHit != null) {
        setState(() => _localErasedLegacy.add(legacyHit));
        widget.onStrokeEnd([const Offset(0, 0), const Offset(0, 1), ..._strip(legacyHit)]);
      }
      return;
    }

    final data = ReaderInkStroke(
      tool: _tool,
      color: _color,
      width: _width,
      opacity: _tool == ReaderInkTool.highlighter ? .28 : 1,
      points: stroke,
    );
    if (widget.onStrokeEndData != null) {
      widget.onStrokeEndData!(data);
    } else {
      widget.onStrokeEnd(_encode(stroke));
    }
  }

  List<Offset> _encode(List<Offset> p) {
    final opacity = _tool == ReaderInkTool.highlighter ? .28 : 1.0;
    final metadata = <Offset>[
      const Offset(.999999, .999999),
      Offset(_tool.index / 10, .5),
      Offset(_color.value / 0xffffffff, .5),
      Offset(_width / 100, .5),
      Offset(opacity, .5),
    ];
    return [...metadata.map((x) => Offset(x.dx * _size.width, x.dy * _size.height)), ...p];
  }

  List<Offset> _strip(List<Offset> p) => p.length >= 5 && p.first.dx > _size.width * .99 && p.first.dy > _size.height * .99 ? p.sublist(5) : p;

  ReaderInkStroke? _hitTyped(List<Offset> eraser) {
    final threshold = mathMax(10, _width * 2.5);
    for (final stored in widget.typedStrokes.reversed) {
      if (_localErasedTyped.any((e) => _sameTyped(e, stored))) continue;
      final target = stored.points;
      if (target.length < 2) continue;
      for (var i = 1; i < target.length; i++) {
        for (var j = 1; j < eraser.length; j++) {
          if (_segmentsNear(target[i - 1], target[i], eraser[j - 1], eraser[j], threshold)) return stored;
        }
      }
    }
    return null;
  }

  List<Offset>? _hitLegacy(List<Offset> eraser) {
    final threshold = mathMax(10, _width * 2.5);
    for (final stored in widget.strokes.reversed) {
      if (_localErasedLegacy.any((e) => _same(e, stored))) continue;
      final target = _strip(stored);
      if (target.length < 2) continue;
      for (var i = 1; i < target.length; i++) {
        for (var j = 1; j < eraser.length; j++) {
          if (_segmentsNear(target[i - 1], target[i], eraser[j - 1], eraser[j], threshold)) return stored;
        }
      }
    }
    return null;
  }

  double mathMax(double a, double b) => a > b ? a : b;

  bool _segmentsNear(Offset a, Offset b, Offset c, Offset d, double threshold) =>
      _dist(a, c, d) <= threshold || _dist(b, c, d) <= threshold || _dist(c, a, b) <= threshold || _dist(d, a, b) <= threshold;

  double _dist(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy, l = dx * dx + dy * dy;
    if (l == 0) return (p - a).distance;
    final q = ((((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / l).clamp(0.0, 1.0).toDouble();
    return (p - Offset(a.dx + q * dx, a.dy + q * dy)).distance;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    _size = Size(c.maxWidth, c.maxHeight);
    final legacy = widget.strokes.where((s) => !_localErasedLegacy.any((e) => _same(e, s))).toList();
    final typed = widget.typedStrokes.where((s) => !_localErasedTyped.any((e) => _sameTyped(e, s))).toList();
    final scheme = Theme.of(context).colorScheme;
    final widths = _tool == ReaderInkTool.highlighter ? const [6.0, 10.0, 16.0] : const [1.6, 2.6, 4.0];
    const colors = [Colors.red, Colors.black, Colors.blue, Colors.green, Colors.orange];
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _Painter(legacyStrokes: legacy, typedStrokes: typed, current: _current, tool: _tool, color: _color, width: _width, size: _size),
          size: Size.infinite,
        ),
        GestureDetector(
          behavior: widget.enabled ? HitTestBehavior.opaque : HitTestBehavior.translucent,
          onPanStart: _start,
          onPanUpdate: _update,
          onPanEnd: _end,
          child: const SizedBox.expand(),
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _button(Icons.edit, '笔', ReaderInkTool.pen),
                  _button(Icons.highlight, '荧光笔', ReaderInkTool.highlighter),
                  _button(Icons.auto_fix_off, '橡皮擦', ReaderInkTool.eraser),
                  const SizedBox(width: 4),
                  for (final color in colors) _colorButton(color),
                  const SizedBox(width: 4),
                  for (final width in widths) _widthButton(width),
                ]),
              ),
            ),
          ),
      ],
    );
  });

  Widget _button(IconData icon, String tooltip, ReaderInkTool tool) => IconButton(
    tooltip: tooltip,
    onPressed: () => setState(() => _tool = tool),
    style: IconButton.styleFrom(backgroundColor: _tool == tool ? Theme.of(context).colorScheme.primaryContainer : null),
    icon: Icon(icon),
  );

  Widget _colorButton(Color color) => Tooltip(
    message: '颜色',
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _color = color),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: _color.value == color.value ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: const SizedBox(width: 14, height: 14),
        ),
      ),
    ),
  );

  Widget _widthButton(double width) => IconButton(
    tooltip: '粗细 ${width.toStringAsFixed(1)}',
    onPressed: () => setState(() => _width = width),
    style: IconButton.styleFrom(backgroundColor: (_width - width).abs() < .01 ? Theme.of(context).colorScheme.primaryContainer : null),
    icon: SizedBox(width: 22, child: Center(child: Container(width: width * 2.2, height: width * 2.2, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)))),
  );

  bool _same(List<Offset> a, List<Offset> b) {
    final x = _strip(a), y = _strip(b);
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) if ((x[i] - y[i]).distance > .5) return false;
    return true;
  }

  bool _sameTyped(ReaderInkStroke a, ReaderInkStroke b) {
    if (a.tool != b.tool || a.color.value != b.color.value || a.points.length != b.points.length) return false;
    for (var i = 0; i < a.points.length; i++) if ((a.points[i] - b.points[i]).distance > .5) return false;
    return true;
  }
}

class _Painter extends CustomPainter {
  final List<List<Offset>> legacyStrokes;
  final List<ReaderInkStroke> typedStrokes;
  final List<Offset> current;
  final ReaderInkTool tool;
  final Color color;
  final double width;
  final Size size;

  const _Painter({required this.legacyStrokes, required this.typedStrokes, required this.current, required this.tool, required this.color, required this.width, required this.size});

  void _drawPath(Canvas c, List<Offset> p, Paint paint) {
    if (p.length < 2) return;
    final path = ui.Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length; i++) {
      final q = p[i], r = p[i - 1], m = Offset((r.dx + q.dx) / 2, (r.dy + q.dy) / 2);
      path.quadraticBezierTo(r.dx, r.dy, m.dx, m.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
    c.drawPath(path, paint);
  }

  Paint _paint(ReaderInkTool t, Color c, double w, double opacity) {
    final p = Paint()
      ..color = c.withValues(alpha: opacity)
      ..strokeWidth = t == ReaderInkTool.highlighter ? w * 3.5 : w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (t == ReaderInkTool.highlighter) p.blendMode = BlendMode.multiply;
    return p;
  }

  @override
  void paint(Canvas c, Size s) {
    for (final stroke in typedStrokes) {
      _drawPath(c, stroke.points, _paint(stroke.tool, stroke.color, stroke.width, stroke.opacity));
    }
    for (final e in legacyStrokes) {
      if (e.length < 2) continue;
      var t = ReaderInkTool.pen;
      var col = Colors.red;
      var w = 2.6;
      var opacity = 1.0;
      var start = 0;
      if (e.length >= 5 && e.first.dx > size.width * .99 && e.first.dy > size.height * .99) {
        t = ReaderInkTool.values[(e[1].dx / size.width * 10).round().clamp(0, 2).toInt()];
        col = Color(((e[2].dx / size.width).clamp(0.0, 1.0) * 0xffffffff).round());
        w = (e[3].dx / size.width).clamp(.001, 1.0) * 100;
        opacity = (e[4].dx / size.width).clamp(.05, 1.0);
        start = 5;
      }
      _drawPath(c, e.sublist(start), _paint(t, col, w, opacity));
    }
    if (current.length >= 2 && tool != ReaderInkTool.eraser) {
      final opacity = tool == ReaderInkTool.highlighter ? .28 : 1.0;
      _drawPath(c, current, _paint(tool, color, width, opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => old.legacyStrokes != legacyStrokes || old.typedStrokes != typedStrokes || old.current != current || old.tool != tool || old.color != color || old.width != width || old.size != size;
}
