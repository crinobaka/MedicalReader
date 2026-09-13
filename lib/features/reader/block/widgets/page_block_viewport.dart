import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/page_block.dart';

/// Displays a rectangular region of the original PDF raster without creating
/// a second page/image identity. The source image remains the complete page.
class PageBlockViewport extends StatelessWidget {
  const PageBlockViewport({
    super.key,
    required this.image,
    required this.block,
    this.scrollPercent = 0,
    this.background = Colors.black,
  });

  final ui.Image image;
  final PageBlock block;
  final double scrollPercent;
  final Color background;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PageBlockPainter(
                image: image,
                rect: block.rect,
                scrollPercent: scrollPercent,
              ),
            );
          },
        ),
      );
}

class _PageBlockPainter extends CustomPainter {
  const _PageBlockPainter({required this.image, required this.rect, required this.scrollPercent});

  final ui.Image image;
  final NormalizedRect rect;
  final double scrollPercent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || image.width == 0 || image.height == 0) return;

    final source = Rect.fromLTWH(
      rect.x * image.width,
      rect.y * image.height,
      rect.width * image.width,
      rect.height * image.height,
    );

    // Preserve the block's source aspect ratio. If the viewport is taller,
    // allow vertical panning within the scaled block; otherwise center it.
    final scale = size.width / source.width;
    final scaledHeight = source.height * scale;
    final maxVerticalOffset = (scaledHeight - size.height).clamp(0.0, double.infinity).toDouble();
    final offsetY = maxVerticalOffset * scrollPercent.clamp(0.0, 1.0);
    final destination = Rect.fromLTWH(0, -offsetY, size.width, scaledHeight);

    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(image, source, destination, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant _PageBlockPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.rect != rect ||
      oldDelegate.scrollPercent != scrollPercent;
}
