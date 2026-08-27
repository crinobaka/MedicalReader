import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/crop_configuration.dart';

/// 可直接操作的裁剪区域画布。
///
/// 区域坐标始终以 PDF 页面本身为基准，而不是以外层画布为基准。
/// 这样在手机竖屏、桌面宽屏以及 BoxFit.contain 留白场景下，
/// 裁剪框都会和实际 PDF 页面严格重合。
class CropRegionCanvas extends StatelessWidget {
  final ui.Image? image;
  final List<CropRegion> regions;
  final ValueChanged<int> onLongPressRegion;
  final void Function(int index, CropRegion region) onChanged;
  final double minRegionSize;
  final double snapDistance;

  const CropRegionCanvas({
    super.key,
    this.image,
    required this.regions,
    required this.onLongPressRegion,
    required this.onChanged,
    this.minRegionSize = 0.04,
    this.snapDistance = 0.018,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final pageRect = _pageRect(canvasSize, image);
        var number = 0;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: image == null
                  ? ColoredBox(color: Theme.of(context).colorScheme.surface)
                  : RawImage(image: image, fit: BoxFit.contain, alignment: Alignment.center),
            ),
            Positioned.fromRect(
              rect: pageRect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
            ...regions.asMap().entries.map((entry) {
              final index = entry.key;
              final region = entry.value.clamp();
              final excluded = region.excluded;
              final label = excluded ? '排除' : '区域 ${++number}';
              final regionRect = Rect.fromLTWH(
                pageRect.left + region.x * pageRect.width,
                pageRect.top + region.y * pageRect.height,
                region.width * pageRect.width,
                region.height * pageRect.height,
              );

              return Positioned.fromRect(
                rect: regionRect,
                child: _RegionGesture(
                  region: region,
                  pageSize: pageRect.size,
                  minRegionSize: minRegionSize,
                  onLongPress: () => onLongPressRegion(index),
                  onChanged: (next) => onChanged(index, _snapRegion(index, next)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: excluded
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      color: excluded
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.75)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                    ),
                    child: Stack(
                      children: [
                        if (excluded)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _CropHatchPainter(
                                Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: excluded ? TextDecoration.lineThrough : null,
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

  CropRegion _snapRegion(int index, CropRegion value) {
    var next = value.clamp();
    final guidesX = <double>[0, 1];
    final guidesY = <double>[0, 1];

    for (var i = 0; i < regions.length; i++) {
      if (i == index) continue;
      final other = regions[i].clamp();
      guidesX.addAll([other.x, other.x + other.width]);
      guidesY.addAll([other.y, other.y + other.height]);
    }

    double snap(double candidate, List<double> guides) {
      var best = candidate;
      var bestDistance = snapDistance;
      for (final guide in guides) {
        final distance = (guide - candidate).abs();
        if (distance <= bestDistance) {
          best = guide;
          bestDistance = distance;
        }
      }
      return best;
    }

    final left = snap(next.x, guidesX);
    final top = snap(next.y, guidesY);
    final right = snap(next.x + next.width, guidesX);
    final bottom = snap(next.y + next.height, guidesY);

    final x = left.clamp(0.0, 1.0);
    final y = top.clamp(0.0, 1.0);
    final rightEdge = right.clamp(x + minRegionSize, 1.0);
    final bottomEdge = bottom.clamp(y + minRegionSize, 1.0);

    return next.copyWith(
      x: x.toDouble(),
      y: y.toDouble(),
      width: (rightEdge - x).toDouble(),
      height: (bottomEdge - y).toDouble(),
    ).clamp();
  }

  Rect _pageRect(Size canvas, ui.Image? image) {
    if (image == null || canvas.isEmpty) return Offset.zero & canvas;
    final imageAspect = image.width / image.height;
    final canvasAspect = canvas.width / canvas.height;

    if (imageAspect > canvasAspect) {
      final width = canvas.width;
      final height = width / imageAspect;
      return Rect.fromLTWH(0, (canvas.height - height) / 2, width, height);
    }

    final height = canvas.height;
    final width = height * imageAspect;
    return Rect.fromLTWH((canvas.width - width) / 2, 0, width, height);
  }
}

class _RegionGesture extends StatefulWidget {
  final CropRegion region;
  final Size pageSize;
  final double minRegionSize;
  final VoidCallback onLongPress;
  final ValueChanged<CropRegion> onChanged;
  final Widget child;

  const _RegionGesture({
    required this.region,
    required this.pageSize,
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
        _resizing = local.dx >= size.width - 28 && local.dy >= size.height - 28;
      },
      onPanUpdate: (details) {
        if (widget.pageSize.isEmpty) return;
        final region = widget.region;
        final dx = details.delta.dx / widget.pageSize.width;
        final dy = details.delta.dy / widget.pageSize.height;

        if (_resizing) {
          final nextWidth = (region.width + dx).clamp(widget.minRegionSize, 1.0 - region.x);
          final nextHeight = (region.height + dy).clamp(widget.minRegionSize, 1.0 - region.y);
          widget.onChanged(region.copyWith(
            width: nextWidth.toDouble(),
            height: nextHeight.toDouble(),
          ));
          return;
        }

        final nextX = (region.x + dx).clamp(0.0, 1.0 - region.width);
        final nextY = (region.y + dy).clamp(0.0, 1.0 - region.height);
        widget.onChanged(region.copyWith(x: nextX.toDouble(), y: nextY.toDouble()));
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
    final paint = Paint()..color = color..strokeWidth = 1;
    for (var offset = -size.height; offset < size.width; offset += 10) {
      canvas.drawLine(Offset(offset, 0), Offset(offset + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropHatchPainter oldDelegate) => oldDelegate.color != color;
}
