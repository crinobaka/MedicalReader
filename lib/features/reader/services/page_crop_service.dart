import 'dart:typed_data';
import 'dart:ui' as ui;

class PageCropService {
  const PageCropService();

  Future<ui.Image> cropWhiteMargins(ui.Image image) async {
    final width = image.width;
    final height = image.height;

    if (width <= 2 || height <= 2) {
      return image;
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      return image;
    }

    final pixels = byteData.buffer.asUint8List();

    final bounds = _detectContentBounds(
      pixels: pixels,
      width: width,
      height: height,
    );

    if (bounds == null) {
      return image;
    }

    final left = bounds.left;
    final top = bounds.top;
    final right = bounds.right;
    final bottom = bounds.bottom;

    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth <= 0 || cropHeight <= 0) {
      return image;
    }

    final removedWidth = width - cropWidth;

    final removedHeight = height - cropHeight;

    // 避免页面本身几乎没有白边时反复创建新 Image。
    if (removedWidth < width * 0.01 && removedHeight < height * 0.01) {
      return image;
    }

    final recorder = ui.PictureRecorder();

    final canvas = ui.Canvas(recorder);

    final sourceRect = ui.Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );

    final destinationRect = ui.Rect.fromLTWH(
      0,
      0,
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );

    canvas.drawImageRect(image, sourceRect, destinationRect, ui.Paint());

    final picture = recorder.endRecording();

    return picture.toImage(cropWidth, cropHeight);
  }

  _CropBounds? _detectContentBounds({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    const whiteThreshold = 245;
    const minimumDarkPixels = 2;

    var left = 0;
    var right = width - 1;
    var top = 0;
    var bottom = height - 1;

    while (left < width &&
        _isWhiteColumn(
          pixels,
          width,
          height,
          left,
          whiteThreshold,
          minimumDarkPixels,
        )) {
      left++;
    }

    while (right >= 0 &&
        _isWhiteColumn(
          pixels,
          width,
          height,
          right,
          whiteThreshold,
          minimumDarkPixels,
        )) {
      right--;
    }

    while (top < height &&
        _isWhiteRow(
          pixels,
          width,
          height,
          top,
          whiteThreshold,
          minimumDarkPixels,
        )) {
      top++;
    }

    while (bottom >= 0 &&
        _isWhiteRow(
          pixels,
          width,
          height,
          bottom,
          whiteThreshold,
          minimumDarkPixels,
        )) {
      bottom--;
    }

    if (left >= right || top >= bottom) {
      return null;
    }

    // 保留少量安全边距，避免把正文边缘裁掉。
    const padding = 8;

    left = (left - padding).clamp(0, width - 1);

    top = (top - padding).clamp(0, height - 1);

    right = (right + padding).clamp(0, width - 1);

    bottom = (bottom + padding).clamp(0, height - 1);

    return _CropBounds(
      left: left,
      top: top,
      right: right + 1,
      bottom: bottom + 1,
    );
  }

  bool _isWhiteColumn(
    Uint8List pixels,
    int width,
    int height,
    int x,
    int threshold,
    int minimumDarkPixels,
  ) {
    var darkPixels = 0;

    final step = height > 100 ? height ~/ 100 : 1;

    for (var y = 0; y < height; y += step) {
      final index = (y * width + x) * 4;

      final r = pixels[index];
      final g = pixels[index + 1];
      final b = pixels[index + 2];

      if (r < threshold || g < threshold || b < threshold) {
        darkPixels++;

        if (darkPixels >= minimumDarkPixels) {
          return false;
        }
      }
    }

    return true;
  }

  bool _isWhiteRow(
    Uint8List pixels,
    int width,
    int height,
    int y,
    int threshold,
    int minimumDarkPixels,
  ) {
    var darkPixels = 0;

    final step = width > 100 ? width ~/ 100 : 1;

    for (var x = 0; x < width; x += step) {
      final index = (y * width + x) * 4;

      final r = pixels[index];
      final g = pixels[index + 1];
      final b = pixels[index + 2];

      if (r < threshold || g < threshold || b < threshold) {
        darkPixels++;

        if (darkPixels >= minimumDarkPixels) {
          return false;
        }
      }
    }

    return true;
  }
}

class _CropBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const _CropBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}
