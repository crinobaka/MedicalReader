import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';

/// 可直接操作的裁剪区域画布。
///
/// - 拖动区域：移动区域
/// - 拖动右下角：调整区域大小
/// - 长按：参与/排除
/// - 排除区域使用斜线表示，不参与最终编号和输出
///
/// PDF 页面通常不会与手机屏幕保持相同宽高比，因此区域必须以
/// `BoxFit.contain` 实际显示出来的页面矩形为坐标系，而不是整个画布。
class CropRegionCanvas extends StatelessWidget {
  final ui.Image? image;
  final List<CropRegion> regions;
  final ValueChanged<int> onLongPressRegion;
  final void Function(int index, CropRegion region) onChanged;
  final double minRegionSize;

  const CropRegionCanvas({
    super.key,
    this.image,
    required this.regions,
    required this.onLongPressRegion,
    required this.onChanged,
    this.minRegionSize = 0.04,
  });

  Rect _imageRect(Size canvasSize) {
    final currentImage = image;
    if (currentImage == null ||
        currentImage.width <= 0 ||
        currentImage.height <= 0 ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return Offset.zero & canvasSize;
    }

    final imageAspect = currentImage.width / currentImage.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    if (imageAspect > canvasAspect) {
      final width = canvasSize.width;
      final height = width / imageAspect;
      return Rect.fromLTWH(
        0,
        (canvasSize.height - height) / 2,
        width,
        height,
      );
    }

    final height = canvasSize.height;
    final width = height * imageAspect;
    return Rect.fromLTWH(
      (canvasSize.width - width) / 2,
      0,
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final pageRect = _imageRect(canvasSize);
        var number = 0;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: image == null
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                    )
                  : RawImage(image: image, fit: BoxFit.contain),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            if (image != null)
              ...regions.asMap().entries.map((entry) {
                final index = entry.key;
                final region = entry.value.clamp();
                final excluded = region.excluded;
                final label = excluded ? '排除' : '区域 ${++number}';

                return Positioned(
                  left: pageRect.left + region.x * pageRect.width,
                  top: pageRect.top + region.y * pageRect.height,
                  width: region.width * pageRect.width,
                  height: region.height * pageRect.height,
                  child: _RegionGesture(
                    region: region,
                    canvasSize: pageRect.size,
                    minRegionSize: minRegionSize,
                    onLongPress: () => onLongPressRegion(index),
                    onChanged: (next) => onChanged(index, next),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: excluded
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        color: excluded
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.75)
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.10),
                      ),
                      child: Stack(
                        children: [
                          if (excluded)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CropHatchPainter(
                                  Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: excluded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (!excluded)
                            const Positioned(
                              right: 2,
                              bottom: 2,
                              child: Icon(Icons.open_in_full, size: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _RegionGesture extends StatefulWidget {
  final CropRegion region;
  final Size canvasSize;
  final double minRegionSize;
  final VoidCallback onLongPress;
  final ValueChanged<CropRegion> onChanged;
  final Widget child;

  const _RegionGesture({
    required this.region,
    required this.canvasSize,
    required this.minRegionSize,
    required this.onLongPress,
    required this.onChanged,
    required this.child,
  });

  @override
  State<_RegionGesture> createState() => _RegionGestureState();
}

class _RegionGestureState extends State<_RegionGesture> {
  bool _resizing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress,
      onPanStart: (details) {
        final local = details.localPosition;
        final size = context.size ?? Size.zero;
        _resizing = local.dx >= size.width - 28 &&
            local.dy >= size.height - 28;
      },
      onPanUpdate: (details) {
        if (widget.canvasSize.width <= 0 || widget.canvasSize.height <= 0) {
          return;
        }

        final region = widget.region;
        final dx = details.delta.dx / widget.canvasSize.width;
        final dy = details.delta.dy / widget.canvasSize.height;

        if (_resizing) {
          final nextWidth = (region.width + dx).clamp(
            widget.minRegionSize,
            1.0 - region.x,
          );
          final nextHeight = (region.height + dy).clamp(
            widget.minRegionSize,
            1.0 - region.y,
          );
          widget.onChanged(
            region.copyWith(
              width: nextWidth.toDouble(),
              height: nextHeight.toDouble(),
            ),
          );
          return;
        }

        final nextX = (region.x + dx).clamp(0.0, 1.0 - region.width);
        final nextY = (region.y + dy).clamp(0.0, 1.0 - region.height);
        widget.onChanged(
          region.copyWith(
            x: nextX.toDouble(),
            y: nextY.toDouble(),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _CropHatchPainter extends CustomPainter {
  final Color color;

  const _CropHatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var offset = -size.height; offset < size.width; offset += 10) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropHatchPainter oldDelegate) =>
      oldDelegate.color != color;
}
