import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controllers/page_block_controller.dart';
import 'page_block_editor.dart';
import 'page_block_loading_overlay.dart';
import 'page_block_viewport.dart';

/// Interactive surface mounted above the normal PDF reader canvas.
/// The underlying PDF page remains the only source of truth; this widget only
/// changes which normalized rectangle is visible.
class PageBlockModeOverlay extends StatefulWidget {
  const PageBlockModeOverlay({
    super.key,
    required this.image,
    required this.controller,
    required this.onClose,
    required this.onPageChanged,
  });

  final ui.Image image;
  final PageBlockController controller;
  final Future<void> Function() onClose;
  final Future<void> Function(int pageIndex) onPageChanged;

  @override
  State<PageBlockModeOverlay> createState() => _PageBlockModeOverlayState();
}

class _PageBlockModeOverlayState extends State<PageBlockModeOverlay> {
  double? _dragStartY;

  PageBlockController get _controller => widget.controller;

  Future<void> _next() async {
    final oldPage = _controller.currentPageIndex;
    if (!await _controller.next() || !mounted) return;
    if (_controller.currentPageIndex != oldPage) {
      await widget.onPageChanged(_controller.currentPageIndex);
    }
  }

  Future<void> _previous() async {
    final oldPage = _controller.currentPageIndex;
    if (!await _controller.previous() || !mounted) return;
    if (_controller.currentPageIndex != oldPage) {
      await widget.onPageChanged(_controller.currentPageIndex);
    }
  }

  Future<void> _edit() async {
    if (_controller.currentBlock == null) return;
    final blocks = await _controller.manager.resolve(
      _controller.docId,
      _controller.currentPageIndex,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        child: PageBlockEditor(
          image: widget.image,
          initialBlocks: blocks,
          onSave: _controller.saveOrderedBlocks,
        ),
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.localPosition.dy;
  }

  Future<void> _onVerticalDragEnd(DragEndDetails details) async {
    final start = _dragStartY;
    _dragStartY = null;
    if (start == null || _controller.currentBlock == null) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() <= 180) return;
    final current = _controller.currentBlock!.scrollPercent;
    await _controller.updateScrollPercent(
      (current + (velocity < 0 ? .18 : -.18)).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final block = _controller.currentBlock;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (block != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -160) {
                    _next();
                  } else if (velocity > 160) {
                    _previous();
                  }
                },
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: PageBlockViewport(
                  image: widget.image,
                  block: block,
                  scrollPercent: block.scrollPercent,
                ),
              )
            else
              const SizedBox.expand(),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(.58),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '上一阅读块',
                      color: Colors.white,
                      onPressed: _controller.loading ? null : _previous,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _controller.internalBlockLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: '下一阅读块',
                      color: Colors.white,
                      onPressed: _controller.loading ? null : _next,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: '编辑阅读块',
                      color: Colors.white,
                      onPressed: _controller.loading ? null : _edit,
                      icon: const Icon(Icons.crop_free),
                    ),
                    IconButton(
                      tooltip: '查看原页',
                      color: Colors.white,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (_controller.loading) const PageBlockLoadingOverlay(),
          ],
        );
      },
    );
  }
}
