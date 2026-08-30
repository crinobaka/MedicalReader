import 'package:flutter/material.dart';

/// GPU-backed platform magnifier. It samples the already-rendered scene rather
/// than rendering the PDF again, so it stays cheap while the user drags it.
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
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: ClipOval(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 12, spreadRadius: 2)],
            ),
            child: RawMagnifier(
              magnificationScale: scale,
              size: Size.square(size),
            ),
          ),
        ),
      ),
    );
  }
}
