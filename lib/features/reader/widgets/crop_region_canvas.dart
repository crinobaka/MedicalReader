import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';
import 'crop_editor_toolbar.dart';

class CropRegionCanvas extends StatefulWidget {
  final ui.Image? image;
  final List<CropRegion> regions;
  final ValueChanged<int> onLongPressRegion;
  final void Function(int index, CropRegion region) onChanged;
  final ValueChanged<CropRegion>? onCreateRegion;
  final CropEditorTool tool;
  final double minRegionSize;
  final double snapDistance;

  const CropRegionCanvas({super.key, this.image, required this.regions, required this.onLongPressRegion, required this.onChanged, this.onCreateRegion, this.tool = CropEditorTool.select, this.minRegionSize = .04, this.snapDistance = .018});

  @override State<CropRegionCanvas> createState() => _CropRegionCanvasState();
}

class _CropRegionCanvasState extends State<CropRegionCanvas> {
  Offset? _start;
  Offset? _current;
  final List<Offset> _polygon = [];

  @override
  void didUpdateWidget(covariant CropRegionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tool != oldWidget.tool && widget.tool != CropEditorTool.polygon) {
      _polygon.clear(); _start = null; _current = null;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final pageRect = _pageRect(Size(constraints.maxWidth, constraints.maxHeight), widget.image);
    var number = 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.tool == CropEditorTool.polygon ? (d) => _polygonTap(d.localPosition, pageRect) : null,
      onPanStart: widget.tool == CropEditorTool.select ? null : (d) => _startDraw(d.localPosition, pageRect),
      onPanUpdate: widget.tool == CropEditorTool.select ? null : (d) => setState(() => _current = d.localPosition),
      onPanEnd: widget.tool == CropEditorTool.select ? null : (_) => _finishDraw(pageRect),
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned.fill(child: widget.image == null ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerLowest) : RawImage(image: widget.image, fit: BoxFit.contain, alignment: Alignment.center)),
        Positioned.fromRect(rect: pageRect, child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)))),
        ...widget.regions.asMap().entries.map((entry) {
          final index = entry.key; final region = entry.value.clamp(); final excluded = region.excluded;
          final label = excluded ? '排除' : '区域 ${++number}';
          final rect = Rect.fromLTWH(pageRect.left + region.x * pageRect.width, pageRect.top + region.y * pageRect.height, region.width * pageRect.width, region.height * pageRect.height);
          return Positioned.fromRect(rect: rect, child: IgnorePointer(ignoring: widget.tool != CropEditorTool.select, child: _RegionGesture(
            region: region, pageSize: pageRect.size, minRegionSize: widget.minRegionSize, onLongPress: () => widget.onLongPressRegion(index), onChanged: (r) => widget.onChanged(index, _snapRegion(index, r)),
            child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: excluded ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.primary, width: 2), color: excluded ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .72) : Theme.of(context).colorScheme.primary.withValues(alpha: .10)), child: Stack(children: [
              if (excluded) Positioned.fill(child: CustomPaint(painter: _CropHatchPainter(Theme.of(context).colorScheme.outline.withValues(alpha: .35)))),
              Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, decoration: excluded ? TextDecoration.lineThrough : null))),
              if (!excluded) const Positioned(right: 2, bottom: 2, child: Icon(Icons.open_in_full, size: 14)),
            ])),
          )));
        }),
        if (_start != null && _current != null) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DrawPreviewPainter(widget.tool, _start!, _current!)))),
        if (_polygon.isNotEmpty) Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PolygonPainter(_polygon, pageRect)))),
      ]),
    );
  });

  void _startDraw(Offset p, Rect pageRect) { if (!pageRect.contains(p)) return; setState(() { _start = p; _current = p; }); }

  void _polygonTap(Offset p, Rect pageRect) {
    if (!pageRect.contains(p)) return;
    final local = Offset(((p.dx - pageRect.left) / pageRect.width).clamp(0.0, 1.0).toDouble(), ((p.dy - pageRect.top) / pageRect.height).clamp(0.0, 1.0).toDouble());
    if (_polygon.length >= 3 && (local - _polygon.first).distance < .025) { _finishPolygon(); return; }
    setState(() => _polygon.add(local));
  }

  void _finishDraw(Rect pageRect) {
    final a = _start, b = _current;
    setState(() { _start = null; _current = null; });
    if (a == null || b == null || widget.onCreateRegion == null) return;
    if (widget.tool == CropEditorTool.line) { _splitByLine(a, b, pageRect); return; }
    final r = Rect.fromPoints(a, b).intersect(pageRect);
    if (r.width < 8 || r.height < 8) return;
    widget.onCreateRegion!(_snapNewRegion(CropRegion(x: ((r.left - pageRect.left) / pageRect.width).clamp(0.0, 1.0).toDouble(), y: ((r.top - pageRect.top) / pageRect.height).clamp(0.0, 1.0).toDouble(), width: (r.width / pageRect.width).clamp(widget.minRegionSize, 1.0).toDouble(), height: (r.height / pageRect.height).clamp(widget.minRegionSize, 1.0).toDouble())));
  }

  void _finishPolygon() {
    if (_polygon.length < 3 || widget.onCreateRegion == null) return;
    var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (final p in _polygon) { minX = minX > p.dx ? p.dx : minX; minY = minY > p.dy ? p.dy : minY; maxX = maxX < p.dx ? p.dx : maxX; maxY = maxY < p.dy ? p.dy : maxY; }
    final r = CropRegion(x: minX, y: minY, width: maxX - minX, height: maxY - minY);
    setState(() => _polygon.clear());
    if (r.width >= widget.minRegionSize && r.height >= widget.minRegionSize) widget.onCreateRegion!(_snapNewRegion(r));
  }

  void _splitByLine(Offset a, Offset b, Rect pageRect) {
    if (widget.onCreateRegion == null) return;
    final vertical = (b.dx - a.dx).abs() > (b.dy - a.dy).abs();
    final t = vertical ? ((a.dx + b.dx) / 2 - pageRect.left) / pageRect.width : ((a.dy + b.dy) / 2 - pageRect.top) / pageRect.height;
    final hit = <int>[];
    for (var i = 0; i < widget.regions.length; i++) { final r = widget.regions[i].clamp(); if (vertical ? t > r.x + widget.minRegionSize && t < r.x + r.width - widget.minRegionSize : t > r.y + widget.minRegionSize && t < r.y + r.height - widget.minRegionSize) hit.add(i); }
    if (hit.isEmpty) return;
    final index = hit.first; final r = widget.regions[index].clamp();
    if (vertical) {
      final left = r.copyWith(width: t - r.x); final right = r.copyWith(x: t, width: r.x + r.width - t);
      widget.onChanged(index, left); widget.onCreateRegion!(right);
    } else {
      final top = r.copyWith(height: t - r.y); final bottom = r.copyWith(y: t, height: r.y + r.height - t);
      widget.onChanged(index, top); widget.onCreateRegion!(bottom);
    }
  }

  CropRegion _snapNewRegion(CropRegion value) => _snapRegion(-1, value);

  CropRegion _snapRegion(int index, CropRegion value) {
    final xs = <double>[0, 1], ys = <double>[0, 1];
    for (var i = 0; i < widget.regions.length; i++) { if (i == index) continue; final r = widget.regions[i].clamp(); xs.addAll([r.x, r.x + r.width]); ys.addAll([r.y, r.y + r.height]); }
    double snap(double v, List<double> guides) { var best = v, d = widget.snapDistance; for (final g in guides) { final delta = (g - v).abs(); if (delta <= d) { best = g; d = delta; } } return best; }
    final x = snap(value.x, xs).clamp(0.0, 1.0 - widget.minRegionSize).toDouble(); final y = snap(value.y, ys).clamp(0.0, 1.0 - widget.minRegionSize).toDouble();
    final right = snap(value.x + value.width, xs).clamp(x + widget.minRegionSize, 1.0).toDouble(); final bottom = snap(value.y + value.height, ys).clamp(y + widget.minRegionSize, 1.0).toDouble();
    return value.copyWith(x: x, y: y, width: right - x, height: bottom - y);
  }

  Rect _pageRect(Size canvas, ui.Image? image) { if (image == null || canvas.isEmpty) return Offset.zero & canvas; final ia = image.width / image.height, ca = canvas.width / canvas.height; if (ia > ca) { final w = canvas.width; return Rect.fromLTWH(0, (canvas.height - w / ia) / 2, w, w / ia); } final h = canvas.height, w = h * ia; return Rect.fromLTWH((canvas.width - w) / 2, 0, w, h); }
}

class _RegionGesture extends StatefulWidget {
  final CropRegion region; final Size pageSize; final double minRegionSize; final VoidCallback onLongPress; final ValueChanged<CropRegion> onChanged; final Widget child;
  const _RegionGesture({required this.region, required this.pageSize, required this.minRegionSize, required this.onLongPress, required this.onChanged, required this.child});
  @override State<_RegionGesture> createState() => _RegionGestureState();
}
class _RegionGestureState extends State<_RegionGesture> {
  bool _resizing = false;
  @override Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onLongPress: widget.onLongPress, onPanStart: (d) { final s = context.size ?? Size.zero; _resizing = d.localPosition.dx >= s.width - 28 && d.localPosition.dy >= s.height - 28; }, onPanUpdate: (d) { if (widget.pageSize.isEmpty) return; final r = widget.region, dx = d.delta.dx / widget.pageSize.width, dy = d.delta.dy / widget.pageSize.height; if (_resizing) widget.onChanged(r.copyWith(width: (r.width + dx).clamp(widget.minRegionSize, 1.0 - r.x).toDouble(), height: (r.height + dy).clamp(widget.minRegionSize, 1.0 - r.y).toDouble())); else widget.onChanged(r.copyWith(x: (r.x + dx).clamp(0.0, 1.0 - r.width).toDouble(), y: (r.y + dy).clamp(0.0, 1.0 - r.height).toDouble())); }, child: widget.child);
}

class _DrawPreviewPainter extends CustomPainter {
  final CropEditorTool tool; final Offset start, current; const _DrawPreviewPainter(this.tool, this.start, this.current);
  @override void paint(Canvas c, Size s) { final p = Paint()..color = Colors.blue..strokeWidth = 3..style = PaintingStyle.stroke; if (tool == CropEditorTool.line) c.drawLine(start, current, p); else c.drawRect(Rect.fromPoints(start, current), p); }
  @override bool shouldRepaint(covariant _DrawPreviewPainter oldDelegate) => true;
}
class _PolygonPainter extends CustomPainter {
  final List<Offset> points; final Rect pageRect; const _PolygonPainter(this.points, this.pageRect);
  @override void paint(Canvas c, Size s) { final p = Paint()..color = Colors.blue..strokeWidth = 2..style = PaintingStyle.stroke; for (var i = 1; i < points.length; i++) c.drawLine(Offset(pageRect.left + points[i-1].dx * pageRect.width, pageRect.top + points[i-1].dy * pageRect.height), Offset(pageRect.left + points[i].dx * pageRect.width, pageRect.top + points[i].dy * pageRect.height), p); }
  @override bool shouldRepaint(covariant _PolygonPainter oldDelegate) => true;
}
class _CropHatchPainter extends CustomPainter {
  final Color color; const _CropHatchPainter(this.color);
  @override void paint(Canvas c, Size s) { final p = Paint()..color = color..strokeWidth = 1; for (var o = -s.height; o < s.width; o += 10) c.drawLine(Offset(o, 0), Offset(o + s.height, s.height), p); }
  @override bool shouldRepaint(covariant _CropHatchPainter oldDelegate) => oldDelegate.color != color;
}
