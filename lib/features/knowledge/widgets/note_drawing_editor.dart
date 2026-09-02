import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/note_drawing.dart';
import '../services/note_drawing_transform_service.dart';

/// Vector note editor. Coordinates remain normalized so drawings survive page-size changes.
class NoteDrawingEditor extends StatefulWidget {
  const NoteDrawingEditor({
    super.key,
    this.initialLayer,
    this.onChanged,
    this.backgroundColor = Colors.white,
  });

  final NoteDrawingLayer? initialLayer;
  final ValueChanged<NoteDrawingLayer>? onChanged;
  final Color backgroundColor;

  @override
  State<NoteDrawingEditor> createState() => _NoteDrawingEditorState();
}

enum _TransformHandle { topLeft, topRight, bottomLeft, bottomRight, rotate }

class _NoteDrawingEditorState extends State<NoteDrawingEditor> {
  late List<NoteDrawingStroke> _strokes;
  final List<List<NoteDrawingStroke>> _undo = [];
  final List<List<NoteDrawingStroke>> _redo = [];
  final _transformer = const NoteDrawingTransformService();

  NoteDrawingTool _tool = NoteDrawingTool.pen;
  Color _color = const Color(0xff202124);
  double _width = 3;
  double _pressure = 1;
  NoteDrawingStroke? _active;
  final List<NoteDrawingPoint> _polygon = [];

  bool _selectMode = false;
  int? _selectedIndex;
  List<NoteDrawingPoint>? _selectionOriginal;
  Offset? _selectionStart;
  bool _selectionCheckpointed = false;

  _TransformHandle? _transformHandle;
  Offset _transformDelta = Offset.zero;
  Size _transformSize = Size.zero;
  Offset _transformHandleStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _strokes = [...?widget.initialLayer?.strokes];
  }

  NoteDrawingLayer get _layer =>
      NoteDrawingLayer(strokes: List.unmodifiable(_strokes));
  void _emit() => widget.onChanged?.call(_layer);

  void _checkpoint() {
    _undo.add(List.of(_strokes));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  NoteDrawingPoint _point(Offset p, Size size) => NoteDrawingPoint(
    size.width <= 0 ? 0 : (p.dx / size.width).clamp(0.0, 1.0),
    size.height <= 0 ? 0 : (p.dy / size.height).clamp(0.0, 1.0),
  );

  void _begin(Offset local, Size size) {
    if (_selectMode) {
      _beginSelection(local, size);
      return;
    }
    if (_tool == NoteDrawingTool.eraser) {
      _eraseAt(local, size);
      return;
    }
    if (_tool == NoteDrawingTool.polygon) {
      setState(() => _polygon.add(_point(local, size)));
      return;
    }
    final p = _point(local, size);
    final pressure = _pressure.clamp(.45, 1.75);
    setState(() {
      _active = NoteDrawingStroke(
        tool: _tool,
        color: _color.toARGB32(),
        width: _width * pressure,
        opacity: _tool == NoteDrawingTool.highlighter ? .28 : 1,
        points: [p],
      );
    });
  }

  void _update(Offset local, Size size) {
    if (_selectMode) {
      _updateSelection(local, size);
      return;
    }
    if (_tool == NoteDrawingTool.eraser) {
      _eraseAt(local, size);
      return;
    }
    final stroke = _active;
    if (stroke == null) return;
    final p = _point(local, size);
    if ((stroke.tool == NoteDrawingTool.pen ||
            stroke.tool == NoteDrawingTool.highlighter) &&
        stroke.points.isNotEmpty &&
        _distance(stroke.points.last, p) < .0012) {
      return;
    }
    final width =
        stroke.tool == NoteDrawingTool.pen ||
            stroke.tool == NoteDrawingTool.highlighter
        ? stroke.width * .78 + (_width * _pressure.clamp(.45, 1.75)) * .22
        : stroke.width;
    setState(
      () => _active = NoteDrawingStroke(
        tool: stroke.tool,
        color: stroke.color,
        width: width,
        opacity: stroke.opacity,
        points:
            stroke.tool == NoteDrawingTool.pen ||
                stroke.tool == NoteDrawingTool.highlighter
            ? [...stroke.points, p]
            : [stroke.points.first, p],
      ),
    );
  }

  void _end() {
    if (_selectMode) {
      _selectionOriginal = null;
      _selectionStart = null;
      _selectionCheckpointed = false;
      return;
    }
    final stroke = _active;
    _active = null;
    if (stroke == null || stroke.points.length < 2) return;
    _checkpoint();
    setState(() => _strokes = [..._strokes, stroke]);
    _emit();
  }

  void _finishPolygon() {
    if (_polygon.length < 3) return;
    _checkpoint();
    final points = [..._polygon, _polygon.first];
    setState(() {
      _strokes = [
        ..._strokes,
        NoteDrawingStroke(
          tool: NoteDrawingTool.polygon,
          color: _color.toARGB32(),
          width: _width,
          points: points,
        ),
      ];
      _polygon.clear();
    });
    _emit();
  }

  double _distance(NoteDrawingPoint a, NoteDrawingPoint b) =>
      math.sqrt((a.x - b.x)*(a.x - b.x) + (a.y - b.y)*(a.y - b.y));

  void _eraseAt(Offset local, Size size) {
    if (_strokes.isEmpty) return;
    final target = _point(local, size);
    final tolerance = math.max(
      .012,
      (_width * 2.5) / math.max(size.width, size.height),
    );
    final index = _strokes.lastIndexWhere((s) => _hit(s, target, tolerance));
    if (index < 0) return;
    _checkpoint();
    setState(() => _strokes.removeAt(index));
    if (_selectedIndex == index) _selectedIndex = null;
    _emit();
  }

  bool _hit(NoteDrawingStroke s, NoteDrawingPoint p, double tolerance) {
    for (var i = 0; i < s.points.length; i++) {
      if (_distance(s.points[i], p) <= tolerance) return true;
      if (i > 0 &&
          _segmentDistance(p, s.points[i - 1], s.points[i]) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  double _segmentDistance(
    NoteDrawingPoint p,
    NoteDrawingPoint a,
    NoteDrawingPoint b,
  ) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return _distance(p, a);
    final t = (((p.x - a.x) * dx) + ((p.y - a.y) * dy)) / len2;
    final u = t.clamp(0.0, 1.0);
    return math.sqrt((p.x - a.x - u * dx)*(p.x - a.x - u * dx) + (p.y - a.y - u * dy)*(p.y - a.y - u * dy));
  }

  void _beginSelection(Offset local, Size size) {
    final target = _point(local, size);
    final tolerance = math.max(
      .018,
      (_width * 3) / math.max(size.width, size.height),
    );
    final index = _strokes.lastIndexWhere((s) => _hit(s, target, tolerance));
    setState(() {
      _selectedIndex = index < 0 ? null : index;
      _selectionStart = local;
      _selectionOriginal = index < 0 ? null : List.of(_strokes[index].points);
      _selectionCheckpointed = false;
    });
  }

  void _updateSelection(Offset local, Size size) {
    final index = _selectedIndex;
    final start = _selectionStart;
    final original = _selectionOriginal;
    if (index == null || start == null || original == null) return;
    final dx = (local.dx - start.dx) / math.max(size.width, 1);
    final dy = (local.dy - start.dy) / math.max(size.height, 1);
    if (dx.abs() < .0001 && dy.abs() < .0001) return;
    if (!_selectionCheckpointed) {
      _checkpoint();
      _selectionCheckpointed = true;
    }
    final stroke = _strokes[index];
    final moved = original
        .map(
          (p) => NoteDrawingPoint(
            (p.x + dx).clamp(0.0, 1.0),
            (p.y + dy).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
    setState(
      () => _strokes[index] = NoteDrawingStroke(
        tool: stroke.tool,
        color: stroke.color,
        width: stroke.width,
        opacity: stroke.opacity,
        points: moved,
      ),
    );
    _emit();
  }

  Rect _selectionRect(Size size) {
    final index = _selectedIndex;
    if (index == null || _strokes[index].points.isEmpty) return Rect.zero;
    final bounds = _transformer.bounds(_strokes[index]);
    return Rect.fromLTRB(
      bounds.minX * size.width,
      bounds.minY * size.height,
      bounds.maxX * size.width,
      bounds.maxY * size.height,
    ).inflate(10);
  }

  void _beginTransform(_TransformHandle handle, Size size) {
    final index = _selectedIndex;
    if (index == null) return;
    final rect = _selectionRect(size);
    final center = rect.center;
    final start = switch (handle) {
      _TransformHandle.topLeft => rect.topLeft,
      _TransformHandle.topRight => rect.topRight,
      _TransformHandle.bottomLeft => rect.bottomLeft,
      _TransformHandle.bottomRight => rect.bottomRight,
      _TransformHandle.rotate => Offset(rect.center.dx, rect.top - 34),
    };
    _checkpoint();
    setState(() {
      _transformHandle = handle;
      _transformDelta = Offset.zero;
      _transformSize = size;
      _transformHandleStart = start;
      _selectionOriginal = List.of(_strokes[index].points);
      _selectionStart = center;
    });
  }

  void _updateTransform(Offset delta) {
    final handle = _transformHandle;
    final index = _selectedIndex;
    final original = _selectionOriginal;
    if (handle == null || index == null || original == null) return;
    _transformDelta += delta;
    final size = _transformSize;
    final rect = _selectionRectFromPoints(original, size).inflate(10);
    final center = rect.center;
    final stroke = _strokes[index];
    NoteDrawingStroke transformed;
    if (handle == _TransformHandle.rotate) {
      final startVector = _transformHandleStart - center;
      final currentVector = (_transformHandleStart + _transformDelta) - center;
      final angle =
          math.atan2(currentVector.dy, currentVector.dx) -
          math.atan2(startVector.dy, startVector.dx);
      transformed = _transformer.rotate(
        NoteDrawingStroke(
          tool: stroke.tool,
          color: stroke.color,
          width: stroke.width,
          opacity: stroke.opacity,
          points: original,
        ),
        angle,
        anchor: _point(center, size),
      );
    } else {
      final startCorner = _transformHandleStart;
      final current = startCorner + _transformDelta;
      final sx0 = (startCorner.dx - center.dx).abs().clamp(
        1.0,
        double.infinity,
      );
      final sy0 = (startCorner.dy - center.dy).abs().clamp(
        1.0,
        double.infinity,
      );
      final sx = ((current.dx - center.dx).abs() / sx0).clamp(.2, 5.0);
      final sy = ((current.dy - center.dy).abs() / sy0).clamp(.2, 5.0);
      transformed = _transformer.scale(
        NoteDrawingStroke(
          tool: stroke.tool,
          color: stroke.color,
          width: stroke.width,
          opacity: stroke.opacity,
          points: original,
        ),
        sx,
        sy,
        anchor: _point(center, size),
      );
    }
    setState(() => _strokes[index] = transformed);
    _emit();
  }

  Rect _selectionRectFromPoints(List<NoteDrawingPoint> points, Size size) {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.x,
        maxX = points.first.x,
        minY = points.first.y,
        maxY = points.first.y;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return Rect.fromLTRB(
      minX * size.width,
      minY * size.height,
      maxX * size.width,
      maxY * size.height,
    );
  }

  void _endTransform() {
    setState(() {
      _transformHandle = null;
      _transformDelta = Offset.zero;
      _selectionOriginal = null;
      _selectionStart = null;
    });
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    _redo.add(List.of(_strokes));
    setState(() {
      _strokes = _undo.removeLast();
      _selectedIndex = null;
    });
    _emit();
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    _undo.add(List.of(_strokes));
    setState(() {
      _strokes = _redo.removeLast();
      _selectedIndex = null;
    });
    _emit();
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _checkpoint();
    setState(() {
      _strokes.clear();
      _selectedIndex = null;
    });
    _emit();
  }

  Future<void> _pickColor() async {
    const colors = <Color>[
      Color(0xff202124),
      Color(0xffd93025),
      Color(0xfff9ab00),
      Color(0xff188038),
      Color(0xff1a73e8),
      Color(0xff9334e6),
      Color(0xffe52592),
      Colors.white,
    ];
    final value = await showModalBottomSheet<Color>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in colors)
                InkWell(
                  onTap: () => Navigator.pop(context, color),
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(backgroundColor: color, radius: 22),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null) setState(() => _color = value);
  }

  Widget _handle(_TransformHandle handle, Offset position, Size size) {
    final rotate = handle == _TransformHandle.rotate;
    return Positioned(
      left: position.dx - (rotate ? 10 : 8),
      top: position.dy - (rotate ? 10 : 8),
      width: rotate ? 20 : 16,
      height: rotate ? 20 : 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _beginTransform(handle, size),
        onPanUpdate: (d) => _updateTransform(d.delta),
        onPanEnd: (_) => _endTransform(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: rotate
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: Icon(
            rotate ? Icons.rotate_right : Icons.circle,
            size: rotate ? 13 : 7,
            color: rotate
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _selectionHandles(Size size) {
    final rect = _selectionRect(size);
    if (_selectedIndex == null || rect == Rect.zero) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        _handle(_TransformHandle.topLeft, rect.topLeft, size),
        _handle(_TransformHandle.topRight, rect.topRight, size),
        _handle(_TransformHandle.bottomLeft, rect.bottomLeft, size),
        _handle(_TransformHandle.bottomRight, rect.bottomRight, size),
        _handle(
          _TransformHandle.rotate,
          Offset(rect.center.dx, rect.top - 30),
          size,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Listener(
                  onPointerDown: (event) {
                    if (event.kind == PointerDeviceKind.stylus ||
                        event.kind == PointerDeviceKind.invertedStylus) {
                      setState(() => _pressure = event.pressure);
                    } else if (_selectMode) {
                      setState(() => _pressure = 1);
                    }
                  },
                  onPointerMove: (event) {
                    if (event.kind == PointerDeviceKind.stylus ||
                        event.kind == PointerDeviceKind.invertedStylus) {
                      final normalized = event.pressureMax > event.pressureMin
                          ? (event.pressure - event.pressureMin) /
                                (event.pressureMax - event.pressureMin)
                          : event.pressure;
                      setState(() => _pressure = normalized.clamp(.0, 1.0));
                    }
                  },
                  onPointerUp: (_) => _pressure = 1,
                  onPointerCancel: (_) => _pressure = 1,
                  child: Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _begin(d.localPosition, size),
                        onPanUpdate: (d) => _update(d.localPosition, size),
                        onPanEnd: (_) => _end(),
                        onTapDown: _selectMode
                            ? (d) => _beginSelection(d.localPosition, size)
                            : null,
                        onDoubleTap:
                            _tool == NoteDrawingTool.polygon && !_selectMode
                            ? _finishPolygon
                            : null,
                        child: CustomPaint(
                          painter: _DrawingPainter(
                            strokes: _strokes,
                            active: _active,
                            polygon: _polygon,
                            color: _color,
                            width: _width,
                            selectedIndex: _selectMode ? _selectedIndex : null,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (_selectMode && _selectedIndex != null)
                        _selectionHandles(size),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 3,
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .96),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.near_me_outlined, size: 18),
                      label: const Text('选择/移动'),
                      selected: _selectMode,
                      onSelected: (value) => setState(() {
                        _selectMode = value;
                        if (!value) _selectedIndex = null;
                        if (_tool == NoteDrawingTool.polygon && value) {
                          _polygon.clear();
                        }
                      }),
                    ),
                    for (final tool in NoteDrawingTool.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(_label(tool)),
                          selected: !_selectMode && _tool == tool,
                          onSelected: (_) => setState(() {
                            _selectMode = false;
                            if (_tool == NoteDrawingTool.polygon) {
                              _polygon.clear();
                            }
                            _tool = tool;
                          }),
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: '撤销',
                      onPressed: _undo.isEmpty ? null : _undoOnce,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: '重做',
                      onPressed: _redo.isEmpty ? null : _redoOnce,
                      icon: const Icon(Icons.redo),
                    ),
                    IconButton(
                      tooltip: '清空当前图层',
                      onPressed: _strokes.isEmpty ? null : _clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                    IconButton(
                      tooltip: '颜色',
                      onPressed: _pickColor,
                      icon: Icon(Icons.palette_outlined, color: _color),
                    ),
                    SizedBox(
                      width: 170,
                      child: Slider(
                        min: 1,
                        max: 18,
                        divisions: 17,
                        value: _width,
                        label: _width.toStringAsFixed(0),
                        onChanged: (v) => setState(() => _width = v),
                      ),
                    ),
                    if (_tool == NoteDrawingTool.polygon && !_selectMode)
                      TextButton.icon(
                        onPressed: _finishPolygon,
                        icon: const Icon(Icons.check),
                        label: const Text('完成多边形'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _label(NoteDrawingTool tool) => switch (tool) {
    NoteDrawingTool.pen => '笔',
    NoteDrawingTool.highlighter => '荧光笔',
    NoteDrawingTool.line => '直线',
    NoteDrawingTool.rectangle => '矩形',
    NoteDrawingTool.ellipse => '椭圆',
    NoteDrawingTool.polygon => '多边形',
    NoteDrawingTool.eraser => '橡皮擦',
  };
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({
    required this.strokes,
    required this.active,
    required this.polygon,
    required this.color,
    required this.width,
    required this.selectedIndex,
  });
  final List<NoteDrawingStroke> strokes;
  final NoteDrawingStroke? active;
  final List<NoteDrawingPoint> polygon;
  final Color color;
  final double width;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < strokes.length; i++) {
      _drawStroke(canvas, size, strokes[i]);
      if (i == selectedIndex) _drawSelection(canvas, size, strokes[i]);
    }
    if (active != null) _drawStroke(canvas, size, active!);
    if (polygon.isNotEmpty) {
      final paint = Paint()
        ..color = color.withValues(alpha: .7)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(polygon.first.x * size.width, polygon.first.y * size.height);
      for (final point in polygon.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawSelection(Canvas canvas, Size size, NoteDrawingStroke stroke) {
    if (stroke.points.isEmpty) return;
    final bounds = _bounds(stroke.points, size).inflate(10);
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(bounds, paint);
  }

  Rect _bounds(List<NoteDrawingPoint> points, Size size) {
    var minX = points.first.x * size.width, maxX = minX;
    var minY = points.first.y * size.height, maxY = minY;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.x * size.width);
      maxX = math.max(maxX, p.x * size.width);
      minY = math.min(minY, p.y * size.height);
      maxY = math.max(maxY, p.y * size.height);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawStroke(Canvas canvas, Size size, NoteDrawingStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = Color(stroke.color).withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = stroke.points.map((p) => p.toOffset(size)).toList();
    if (stroke.tool == NoteDrawingTool.line && points.length >= 2) {
      canvas.drawLine(points.first, points.last, paint);
      return;
    }
    if (stroke.tool == NoteDrawingTool.rectangle && points.length >= 2) {
      canvas.drawRect(Rect.fromPoints(points.first, points.last), paint);
      return;
    }
    if (stroke.tool == NoteDrawingTool.ellipse && points.length >= 2) {
      canvas.drawOval(Rect.fromPoints(points.first, points.last), paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.active != active ||
      oldDelegate.polygon != polygon ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.selectedIndex != selectedIndex;
}
