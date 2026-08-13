import 'dart:typed_data';
import 'dart:ui' as ui;

import 'medical_core.dart';

class MedicalCoreImage {
  const MedicalCoreImage._();

  static Future<ui.Image> decode(MedicalCorePage page) async {
    if (page.width <= 0 || page.height <= 0) {
      throw StateError(
        'Invalid rendered page size: '
        '${page.width}x${page.height}',
      );
    }

    if (page.stride <= 0) {
      throw StateError('Invalid rendered page stride: ${page.stride}');
    }

    if (page.components != 3 && page.components != 4) {
      throw UnsupportedError(
        'Unsupported MuPDF pixel format: '
        '${page.components} components.',
      );
    }

    final minimumRowBytes = page.width * page.components;

    if (page.stride < minimumRowBytes) {
      throw StateError(
        'Invalid rendered page stride: '
        '${page.stride} < $minimumRowBytes',
      );
    }

    final expectedDataLength = page.stride * page.height;

    if (page.data.length < expectedDataLength) {
      throw StateError(
        'Rendered page data is too short: '
        '${page.data.length} < $expectedDataLength',
      );
    }

    final rgba = Uint8List(page.width * page.height * 4);

    for (var y = 0; y < page.height; y++) {
      final sourceRowStart = y * page.stride;

      final targetRowStart = y * page.width * 4;

      for (var x = 0; x < page.width; x++) {
        final sourcePixel = sourceRowStart + x * page.components;

        final targetPixel = targetRowStart + x * 4;

        rgba[targetPixel] = page.data[sourcePixel];

        rgba[targetPixel + 1] = page.data[sourcePixel + 1];

        rgba[targetPixel + 2] = page.data[sourcePixel + 2];

        rgba[targetPixel + 3] = page.components == 4
            ? page.data[sourcePixel + 3]
            : 255;
      }
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);

    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: page.width,
      height: page.height,
      rowBytes: page.width * 4,
      pixelFormat: ui.PixelFormat.rgba8888,
    );

    try {
      final codec = await descriptor.instantiateCodec();

      try {
        final frame = await codec.getNextFrame();

        return frame.image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
