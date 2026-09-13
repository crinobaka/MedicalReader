import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/page_block.dart';

/// Full-page editor: draw any number of rectangles, then drag the cards below
/// to change reading order. All geometry is stored in normalized page space.
class PageBlockEditor extends StatefulWidget {
  const PageBlockEditor({
    super.key,
    required this.image,
    required this.initialBlocks,
    required this.onSave,
  });

  final ui.Image image;
  final List<PageBlock> initialBlocks;
  final Future<void> Function(List<PageBlock> blocks) onSave;

  @override
  State<PageBlockEditor> createState() => _PageBlockEditorState();
}

class _PageBlockEditorState extends State<PageBlockEditor> {
  late List<PageBlock> _blocks;
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void initState() {
    super.initState();
    _blocks = [...widget.initialBlocks];
  }

  void _finishRect(Size size) {
    final start = _dragStart;
    final end = _dragCurrent;
    if (start == null || end == null) return;
    final left = (start.dx / size.width).clamp(0.0, 1.0).toDouble();
    final top = (start.dy / size.height).clamp(0.0, 1.0).toDouble();
    final right = (end.dx / size.width).clamp(0.0, 1.0).toDouble();
    final bottom = (end.dy / size.height).clamp(0.0, 1.0).toDouble();
    final rect = NormalizedRect(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    ).normalized();
    if (rect.width < .02 || rect.height < .02) return;
    setState(() {
      final nextIndex = _blocks.length;
      _blocks.add(PageBlock(
        docId: widget.initialBlocks.firstOrNull?.docId ?? '',
        pageIndex: widget.initialBlocks.firstOrNull?.pageIndex ?? 0,
        blockIndex: nextIndex,
        rect: rect,
        order: nextIndex + 1,
        source: PageBlockSource.manual,
      ));
      _reindex();
    });
  }

  void _reindex() {
    _blocks = [
      for (var i = 0; i < _blocks.length; i++)
        _blocks[i].copyWith(blockIndex: i, order: i + 1, source: PageBlockSource.manual),
    ];
  }

  void _deleteAt(int index) {
    setState(() {
      _blocks.removeAt(index);
      _reindex();
    });
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
          IconButton(onPressed: _blocks.isEmpty ? null : _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: widget.image.width / widget.image.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => setState(() {
                        _dragStart = d.localPosition;
                        _dragCurrent = d.localPosition;
                      }),
                      onPanUpdate: (d) => setState(() => _dragCurrent = d.localPosition),
                      onPanEnd: (_) {
                        _finishRect(size);
                        setState(() {
                          _dragStart = null;
                          _dragCurrent = null;
                        });
                      },
                      child: CustomPaint(
                        painter: _BlockEditorPainter(
                          image: widget.image,
                          blocks: _blocks,
                          draftStart: _dragStart,
                          draftEnd: _dragCurrent,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('在原页上拖动绘制任意数量的阅读块，再拖动下方项目调整顺序。'),
            ),
          ),
          Expanded(
            flex: 2,
            child: ReorderableListView.builder(
              itemCount: _blocks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _blocks.removeAt(oldIndex);
                  _blocks.insert(newIndex, item);
                  _reindex();
                });
              },
              itemBuilder: (context, index) {
                final block = _blocks[index];
                return ListTile(
                  key: ValueKey('${block.pageIndex}-${block.blockIndex}-${block.rect.x}-${block.rect.y}'),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${block.pageIndex + 1}(${index + 1})'),
                  subtitle: Text(
                    'x ${block.rect.x.toStringAsFixed(2)}  y ${block.rect.y.toStringAsFixed(2)}  '
                    'w ${block.rect.width.toStringAsFixed(2)}  h ${block.rect.height.toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteAt(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockEditorPainter extends CustomPainter {
  const _BlockEditorPainter({
    required this.image,
    required this.blocks,
    this.draftStart,
    this.draftEnd,
  });

  final ui.Image image;
  final List<PageBlock> blocks;
  final Offset? draftStart;
  final Offset? draftEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), full, Paint());
    final fill = Paint()..style = PaintingStyle.fill..color = Colors.black.withOpacity(.12);
    final border = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white;
    for (var i = 0; i < blocks.length; i++) {
      final r = blocks[i].rect;
      final rect = Rect.fromLTWH(r.x * size.width, r.y * size.height, r.width * size.width, r.height * size.height);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
      final tp = TextPainter(text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, rect.topLeft + const Offset(6, 4));
    }
    if (draftStart != null && draftEnd != null) {
      final rect = Rect.fromPoints(draftStart!, draftEnd!);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(covariant _BlockEditorPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.blocks != blocks || oldDelegate.draftStart != draftStart || oldDelegate.draftEnd != draftEnd;
}
