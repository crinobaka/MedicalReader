import 'package:flutter/material.dart';

/// Magnifies the already-rendered reader scene without rendering the PDF again.
class ReaderMagnifierOverlay extends StatelessWidget {
  final Offset position;
  final double scale;
  final double size;

  const ReaderMagnifierOverlay({
    super.key,
    required this.position,
    this.scale = 2.4,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.primary;
    const gap = 24.0;
    final top = position.dy - size - gap;
    return Positioned(
      left: position.dx - size / 2,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: RawMagnifier(
          size: Size.square(size),
          magnificationScale: scale,
          focalPointOffset: Offset(0, size / 2 + gap),
          clipBehavior: Clip.hardEdge,
          decoration: MagnifierDecoration(
            shape: CircleBorder(
              side: BorderSide(color: border, width: 3),
            ),
            shadows: const [
              BoxShadow(blurRadius: 12, spreadRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}
