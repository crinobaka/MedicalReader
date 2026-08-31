import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/note_drawing.dart';

class NoteDrawingEditor extends StatefulWidget {
  const NoteDrawingEditor({super.key, this.initialLayer});
  final NoteDrawingLayer? initialLayer;

  @override
  State<NoteDrawingEditor> createState() => _NoteDrawingEditorState();
}

class _NoteDrawingEditorState extends State<NoteDrawingEditor> {
  late List<NoteDrawingStroke> _strokes;
  final List<NoteDrawingStroke> _redo = [];
  NoteDrawingTool _tool = NoteDrawingTool.pen;
  Color _color = const Color(0xff202124);
  double _width = 3;
  NoteDrawingStroke? _active;

  @override
  void initState() {
    super.initState();
    _strokes = widget.initialLayer == null ? <NoteDrawingStroke>[] : [...widget.initialLayer!.strokes];
  }

  void _begin(Offset local, Size size) {
    if (_tool == NoteDrawingTool.eraser) {
      _eraseAt(local, size);
      return;
    }
    _active = NoteDrawingStroke(tool: _tool, color: _color.value, width: _tool == NoteDrawingTool.highlighter ? _width * 3 : _width, opacity: _tool == NoteDrawingTool.highlighter ? .28 : 1, points: [_point(local, size)]);
    setState(() {});
  }

  void _update(Offset local, Size size) {
    if (_tool == NoteDrawingTool.eraser) {
      _eraseAt(local, size);
      return;
    }
    final stroke = _active;
    if (stroke == null) return;
    _active = NoteDrawingStroke(tool: stroke.tool, color: stroke.color, width: stroke.width, opacity: stroke.opacity, points: [...stroke.points, _point(local, size)]);
    setState(() {});
  }

  void _end() {
    final stroke = _active;
    _active = null;
    if (stroke == null || stroke.points.length < 2) return;
    setState(() { _strokes = [..._strokes, stroke]; _redo.clear(); });
  }

  NoteDrawingPoint _point(Offset p, Size size) => NoteDrawingPoint(size.width == 0 ? 0 : (p.dx / size.width).clamp(0, 1), size.height == 0 ? 0 : (p.dy / size.height).clamp(0, 1));

  void _eraseAt(Offset local, Size size) {
    if (_strokes.isEmpty) return;
    final radius = math.max(8, _width * 2.5);
    final removed = <NoteDrawingStroke>[];
    final kept = <NoteDrawingStroke>[];
    for (final stroke in _strokes) {
      final hit = stroke.points.any((p) => (p.toOffset(size) - local).distance <= radius);
      (hit ? removed : kept).add(stroke);
    }
    if (removed.isNotEmpty) setState(() { _redo.addAll(removed); _strokes = kept; });
  }

  void _undo() { if (_strokes.isEmpty) return; setState(() { _redo.add(_strokes.removeLast()); }); }
  void _redoStroke() { if (_redo.isEmpty) return; setState(() { _strokes = [..._strokes, _redo.removeLast()]; }); }

  Future<void> _pickColor() async {
    const colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.white];
    final value = await showModalBottomSheet<Color>(context: context, builder: (_) => SafeArea(child: Wrap(padding: const EdgeInsets.all(16), spacing: 12, children: [for (final color in colors) InkWell(onTap: () => Navigator.pop(context, color), borderRadius: BorderRadius.circular(24), child: CircleAvatar(backgroundColor: color, radius: 22))])));
    if (value != null) setState(() => _color = value);
  }

  @override
  Widget build(BuildContext context) {
    const tools = NoteDrawingTool.values;
    return Scaffold(
      appBar: AppBar(title: const Text('手绘笔记'), actions: [
        IconButton(tooltip: '撤销', onPressed: _strokes.isEmpty ? null : _undo, icon: const Icon(Icons.undo)),
        IconButton(tooltip: '重做', onPressed: _redo.isEmpty ? null : _redoStroke, icon: const Icon(Icons.redo)),
        IconButton(tooltip: '清空当前图层', onPressed: _strokes.isEmpty ? null : () => setState(() { _redo.addAll(_strokes); _strokes.clear(); }), icon: const Icon(Icons.delete_sweep_outlined)),
        IconButton(tooltip: '完成', onPressed: () => Navigator.pop(context, NoteDrawingLayer(strokes: List.unmodifiable(_strokes))), icon: const Icon(Icons.check)),
      ]),
      body: Column(children: [
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(behavior: HitTestBehavior.opaque, onPanStart: (d) => _begin(d.localPosition, size), onPanUpdate: (d) => _update(d.localPosition, size), onPanEnd: (_) => _end(), child: CustomPaint(painter: _DrawingPainter([..._strokes, if (_active != null) _active!]), size: size));
        })),
        SafeArea(top: false, child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
          for (final tool in tools) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: ChoiceChip(label: Text(_label(tool)), selected: _tool == tool, onSelected: (_) => setState(() => _tool = tool))),
          const SizedBox(width: 8), IconButton(tooltip: '颜色', onPressed: _pickColor, icon: Icon(Icons.palette_outlined, color: _color)),
          SizedBox(width: 150, child: Row(children: [const Text('粗细'), Expanded(child: Slider(min: 1, max: 18, value: _width, onChanged: (v) => setState(() => _width = v)))])),
        ]))),
      ]),
    );
  }

  String _label(NoteDrawingTool tool) => switch (tool) { NoteDrawingTool.pen => '笔', NoteDrawingTool.highlighter => '荧光笔', NoteDrawingTool.line => '直线', NoteDrawingTool.rectangle => '矩形', NoteDrawingTool.ellipse => '椭圆', NoteDrawingTool.polygon => '多边形', NoteDrawingTool.eraser => '橡皮擦' };
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter(this.strokes);
  final List<NoteDrawingStroke> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.srcOver);
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()..color = Color(stroke.color).withOpacity(stroke.opacity)..strokeWidth = stroke.width..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final points = stroke.points.map((p) => p.toOffset(size)).toList();
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      if (stroke.tool == NoteDrawingTool.line) {
        path.lineTo(points.last.dx, points.last.dy);
      } else if (stroke.tool == NoteDrawingTool.rectangle || stroke.tool == NoteDrawingTool.ellipse) {
        final rect = Rect.fromPoints(points.first, points.last);
        if (stroke.tool == NoteDrawingTool.rectangle) path.addRect(rect); else path.addOval(rect);
      } else {
        for (final p in points.skip(1)) path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
