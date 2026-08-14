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

    final cropWidth = bounds.right - bounds.left;

    final cropHeight = bounds.bottom - bounds.top;

    if (cropWidth <= 0 || cropHeight <= 0) {
      return image;
    }

    final removedWidth = width - cropWidth;

    final removedHeight = height - cropHeight;

    // 页面本身几乎没有边缘空白。
    if (removedWidth < width * 0.015 && removedHeight < height * 0.015) {
      return image;
    }

    final recorder = ui.PictureRecorder();

    final canvas = ui.Canvas(recorder);

    final sourceRect = ui.Rect.fromLTWH(
      bounds.left.toDouble(),
      bounds.top.toDouble(),
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
    // 每条边最多检查到页面的 20%。
    final maxHorizontalMargin = (width * 0.20).round();

    final maxVerticalMargin = (height * 0.20).round();

    var left = 0;
    var right = width - 1;
    var top = 0;
    var bottom = height - 1;

    left = _findLeftContentEdge(
      pixels: pixels,
      width: width,
      height: height,
      maxMargin: maxHorizontalMargin,
    );

    right = _findRightContentEdge(
      pixels: pixels,
      width: width,
      height: height,
      maxMargin: maxHorizontalMargin,
    );

    top = _findTopContentEdge(
      pixels: pixels,
      width: width,
      height: height,
      maxMargin: maxVerticalMargin,
    );

    bottom = _findBottomContentEdge(
      pixels: pixels,
      width: width,
      height: height,
      maxMargin: maxVerticalMargin,
    );

    if (left >= right || top >= bottom) {
      return null;
    }

    const padding = 12;

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

  int _findLeftContentEdge({
    required Uint8List pixels,
    required int width,
    required int height,
    required int maxMargin,
  }) {
    for (var x = 0; x < maxMargin; x++) {
      final density = _columnContentDensity(pixels, width, height, x);

      if (density > 0.015) {
        return x;
      }
    }

    return 0;
  }

  int _findRightContentEdge({
    required Uint8List pixels,
    required int width,
    required int height,
    required int maxMargin,
  }) {
    for (var offset = 0; offset < maxMargin; offset++) {
      final x = width - 1 - offset;

      final density = _columnContentDensity(pixels, width, height, x);

      if (density > 0.015) {
        return x;
      }
    }

    return width - 1;
  }

  int _findTopContentEdge({
    required Uint8List pixels,
    required int width,
    required int height,
    required int maxMargin,
  }) {
    for (var y = 0; y < maxMargin; y++) {
      final density = _rowContentDensity(pixels, width, height, y);

      if (density > 0.015) {
        return y;
      }
    }

    return 0;
  }

  int _findBottomContentEdge({
    required Uint8List pixels,
    required int width,
    required int height,
    required int maxMargin,
  }) {
    for (var offset = 0; offset < maxMargin; offset++) {
      final y = height - 1 - offset;

      final density = _rowContentDensity(pixels, width, height, y);

      if (density > 0.015) {
        return y;
      }
    }

    return height - 1;
  }

  double _columnContentDensity(Uint8List pixels, int width, int height, int x) {
    var contentPixels = 0;
    var samples = 0;

    final step = height > 300 ? height ~/ 300 : 1;

    for (var y = 0; y < height; y += step) {
      final index = (y * width + x) * 4;

      if (_isContentPixel(
        pixels[index],
        pixels[index + 1],
        pixels[index + 2],
      )) {
        contentPixels++;
      }

      samples++;
    }

    if (samples == 0) {
      return 0;
    }

    return contentPixels / samples;
  }

  double _rowContentDensity(Uint8List pixels, int width, int height, int y) {
    var contentPixels = 0;
    var samples = 0;

    final step = width > 300 ? width ~/ 300 : 1;

    for (var x = 0; x < width; x += step) {
      final index = (y * width + x) * 4;

      if (_isContentPixel(
        pixels[index],
        pixels[index + 1],
        pixels[index + 2],
      )) {
        contentPixels++;
      }

      samples++;
    }

    if (samples == 0) {
      return 0;
    }

    return contentPixels / samples;
  }

  bool _isContentPixel(int r, int g, int b) {
    // 对灰白扫描背景更宽容。
    final luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);

    // 明显偏暗的像素视为正文/图像内容。
    if (luminance < 215) {
      return true;
    }

    // 对偏色、扫描阴影、压缩噪声保持一定敏感度。
    final maxChannel = [r, g, b].reduce((a, b) => a > b ? a : b);

    final minChannel = [r, g, b].reduce((a, b) => a < b ? a : b);

    return maxChannel - minChannel > 18 && luminance < 235;
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
