import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays the currently rendered PDF page without owning reader state.
class ReaderPageImage extends StatelessWidget {
  final ui.Image image;
  final Widget? overlay;

  const ReaderPageImage({
    super.key,
    required this.image,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RawImage(image: image, fit: BoxFit.contain),
        if (overlay != null)
          Positioned.fill(child: overlay!),
      ],
    );
  }
}
