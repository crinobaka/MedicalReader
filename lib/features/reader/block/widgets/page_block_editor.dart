import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/page_block.dart';

class PageBlockEditor extends StatefulWidget {
  const PageBlockEditor({super.key, required this.image, required this.initialBlocks, required this.onSave});

  final ui.Image image;
  final List<PageBlock> initialBlocks;
  final Future<void> Function(List<PageBlock> blocks) onSave;

  @override
  State<PageBlockEditor> createState() => _PageBlockEditorState();
}

class _PageBlockEditorState extends State<PageBlockEditor> {
  static const _minSize = .03;
  static const _hitSize = 28.0;

  late List<PageBlock> _blocks;
  int? _selectedIndex;
  _EditMode _mode = _EditMode.none;
  Offset? _gestureStart;
  NormalizedRect? _gestureRect;

  @override
  void initState() {
    super.initState();
    _blocks = [...widget.initialBlocks];
  }

  Rect _toRect(NormalizedRect r, Size size) => Rect.fromLTWH(r.x * size.width, r.y * size.height, r.width * size.width, r.height * size.height);

  int? _hitBlock(Offset p, Size size) {
    for (var i = _blocks.length - 1; i >= 0; i--) {
      if (_toRect(_blocks[i].rect, size).contains(p)) return i;
    }
    return null;
  }

  _EditMode _hitMode(int index, Offset p, Size size) {
    final rect = _toRect(_blocks[index].rect, size);
    final nearRight = (p.dx - rect.right).abs() <= _hitSize;
    final nearBottom = (p.dy - rect.bottom).abs() <= _hitSize;
    final nearLeft = (p.dx - rect.left).abs() <= _hitSize;
    final nearTop = (p.dy - rect.top).abs() <= _hitSize;
    if (nearRight && nearBottom) return _EditMode.resizeBottomRight;
    if (nearLeft && nearBottom) return _EditMode.resizeBottomLeft;
    if (nearRight && nearTop) return _EditMode.resizeTopRight;
    if (nearLeft && nearTop) return _EditMode.resizeTopLeft;
    return _EditMode.move;
  }

  void _begin(Offset p, Size size) {
    final hit = _hitBlock(p, size);
    if (hit == null) {
      _selectedIndex = null;
      _mode = _EditMode.create;
      _gestureStart = p;
      _gestureRect = null;
      setState(() {});
      return;
    }
    _selectedIndex = hit;
    _mode = _hitMode(hit, p, size);
    _gestureStart = p;
    _gestureRect = _blocks[hit].rect;
    setState(() {});
  }

  void _update(Offset p, Size size) {
    final start = _gestureStart;
    if (start == null) return;
    if (_mode == _EditMode.create) return;
    final index = _selectedIndex;
    final original = _gestureRect;
    if (index == null || original == null) return;
    final dx = (p.dx - start.dx) / size.width;
    final dy = (p.dy - start.dy) / size.height;
    var r = original;
    if (_mode == _EditMode.move) {
      r = NormalizedRect(x: original.x + dx, y: original.y + dy, width: original.width, height: original.height);
    } else {
      var left = original.x, top = original.y, right = original.right, bottom = original.bottom;
      if (_mode == _EditMode.resizeTopLeft || _mode == _EditMode.resizeBottomLeft) left += dx;
      if (_mode == _EditMode.resizeTopRight || _mode == _EditMode.resizeBottomRight) right += dx;
      if (_mode == _EditMode.resizeTopLeft || _mode == _EditMode.resizeTopRight) top += dy;
      if (_mode == _EditMode.resizeBottomLeft || _mode == _EditMode.resizeBottomRight) bottom += dy;
      r = NormalizedRect(x: left, y: top, width: right - left, height: bottom - top).normalized();
    }
    r = r.normalized();
    if (r.width < _minSize || r.height < _minSize) return;
    setState(() => _blocks[index] = _blocks[index].copyWith(rect: r));
  }

  void _end(Offset p, Size size) {
    if (_mode == _EditMode.create && _gestureStart != null) {
      final a = _gestureStart!;
      final left = (a.dx / size.width).clamp(0.0, 1.0).toDouble();
      final top = (a.dy / size.height).clamp(0.0, 1.0).toDouble();
      final right = (p.dx / size.width).clamp(0.0, 1.0).toDouble();
      final bottom = (p.dy / size.height).clamp(0.0, 1.0).toDouble();
      final rect = NormalizedRect(x: left, y: top, width: right - left, height: bottom - top).normalized();
      if (rect.width >= _minSize && rect.height >= _minSize) {
        final source = _blocks.isEmpty ? widget.initialBlocks : _blocks;
        final docId = source.isEmpty ? '' : source.first.docId;
        final pageIndex = source.isEmpty ? 0 : source.first.pageIndex;
        _blocks.add(PageBlock(docId: docId, pageIndex: pageIndex, blockIndex: _blocks.length, rect: rect, order: _blocks.length + 1, source: PageBlockSource.manual));
        _reindex();
        _selectedIndex = _blocks.length - 1;
      }
    }
    _mode = _EditMode.none;
    _gestureStart = null;
    _gestureRect = null;
    setState(() {});
  }

  void _reindex() {
    _blocks = [for (var i = 0; i < _blocks.length; i++) _blocks[i].copyWith(blockIndex: i, order: i + 1, source: PageBlockSource.manual)];
  }

  Future<void> _save() async {
    await widget.onSave(_blocks);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑阅读块'),
        actions: [
          if (_selectedIndex != null) IconButton(tooltip: '删除当前块', onPressed: () { setState(() { _blocks.removeAt(_selectedIndex!); _selectedIndex = null; _reindex(); }); }, icon: const Icon(Icons.delete_outline)),
          IconButton(tooltip: '保存', onPressed: _blocks.isEmpty ? null : _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: widget.image.width / widget.image.height,
                child: LayoutBuilder(builder: (context, constraints) {
                  final size = constraints.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) { final hit = _hitBlock(d.localPosition, size); setState(() => _selectedIndex = hit); },
                    onPanStart: (d) => _begin(d.localPosition, size),
                    onPanUpdate: (d) => _update(d.localPosition, size),
                    onPanEnd: (d) => _end(d.localPosition, size),
                    child: CustomPaint(painter: _BlockEditorPainter(image: widget.image, blocks: _blocks, selectedIndex: _selectedIndex, draftStart: _mode == _EditMode.create ? _gestureStart : null, draftEnd: _mode == _EditMode.create ? _gestureStart : null)),
                  );
                }),
              ),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('点按选择；拖动块移动；拖四角缩放；在空白处拖动新建。列表可直接拖动排序。')),
          Expanded(
            flex: 2,
            child: ReorderableListView.builder(
              itemCount: _blocks.length,
              onReorder: (oldIndex, newIndex) => setState(() { if (newIndex > oldIndex) newIndex--; final item = _blocks.removeAt(oldIndex); _blocks.insert(newIndex, item); _reindex(); _selectedIndex = newIndex; }),
              itemBuilder: (context, index) {
                final block = _blocks[index];
                return ListTile(
                  key: ValueKey('${block.pageIndex}-${block.blockIndex}-${block.rect.x}-${block.rect.y}'),
                  selected: index == _selectedIndex,
                  onTap: () => setState(() => _selectedIndex = index),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${block.pageIndex + 1}(${index + 1})'),
                  subtitle: Text('x ${block.rect.x.toStringAsFixed(2)}  y ${block.rect.y.toStringAsFixed(2)}  w ${block.rect.width.toStringAsFixed(2)}  h ${block.rect.height.toStringAsFixed(2)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)), IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() { _blocks.removeAt(index); _reindex(); if (_selectedIndex == index) _selectedIndex = null; }))]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _EditMode { none, create, move, resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight }

class _BlockEditorPainter extends CustomPainter {
  const _BlockEditorPainter({required this.image, required this.blocks, this.selectedIndex, this.draftStart, this.draftEnd});

  final ui.Image image;
  final List<PageBlock> blocks;
  final int? selectedIndex;
  final Offset? draftStart;
  final Offset? draftEnd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), Offset.zero & size, Paint());
    final fill = Paint()..style = PaintingStyle.fill..color = Colors.black.withOpacity(.14);
    final border = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white;
    for (var i = 0; i < blocks.length; i++) {
      final r = blocks[i].rect;
      final rect = Rect.fromLTWH(r.x * size.width, r.y * size.height, r.width * size.width, r.height * size.height);
      canvas.drawRect(rect, fill);
      final selected = i == selectedIndex;
      border.strokeWidth = selected ? 3 : 2;
      canvas.drawRect(rect, border);
      final tp = TextPainter(text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, rect.topLeft + const Offset(6, 4));
      if (selected) {
        final handle = Paint()..style = PaintingStyle.fill..color = Colors.white;
        for (final point in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) canvas.drawCircle(point, 7, handle);
      }
    }
    if (draftStart != null && draftEnd != null && draftStart != draftEnd) {
      final rect = Rect.fromPoints(draftStart!, draftEnd!);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(covariant _BlockEditorPainter oldDelegate) => true;
}
