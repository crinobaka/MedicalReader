import 'dart:ui' as ui;

import '../models/crop_configuration.dart';

/// Crop Engine：只处理“怎么算裁剪”，不修改原始 PDF。
///
/// 设计成独立服务后，Reader、设置页和以后真正的裁剪编辑器都可以复用同一套规则。
class CropEngineService {
  const CropEngineService();

  List<CropRegion> defaultRegions(CropTemplate template) {
    switch (template) {
      case CropTemplate.single:
      case CropTemplate.bookTemplate:
        return const [
          CropRegion(x: 0, y: 0, width: 1, height: 1),
        ];
      case CropTemplate.doubleColumn:
        return const [
          CropRegion(x: 0, y: 0, width: 0.5, height: 1),
          CropRegion(x: 0.5, y: 0, width: 0.5, height: 1),
        ];
      case CropTemplate.tripleColumn:
        return const [
          CropRegion(x: 0, y: 0, width: 1 / 3, height: 1),
          CropRegion(x: 1 / 3, y: 0, width: 1 / 3, height: 1),
          CropRegion(x: 2 / 3, y: 0, width: 1 / 3, height: 1),
        ];
      case CropTemplate.custom:
        return const [];
    }
  }

  /// 解析当前页最终应该使用的裁剪区域。
  ///
  /// inheritPrevious=true 时，如果本页没有自己的 regions，直接继承上一页，
  /// 然后再应用 adjustment，从而实现“套用当前裁剪 + 微调”。
  List<CropRegion> resolveRegions({
    required CropConfiguration configuration,
    int? pageIndex,
    List<CropRegion>? previousRegions,
  }) {
    if (pageIndex != null && configuration.pageStart != null &&
        pageIndex < configuration.pageStart!) {
      return const [];
    }

    if (pageIndex != null && configuration.pageEnd != null &&
        pageIndex > configuration.pageEnd!) {
      return const [];
    }

    final source = configuration.inheritPrevious &&
            previousRegions != null &&
            previousRegions.isNotEmpty
        ? previousRegions
        : configuration.regions.isNotEmpty
            ? configuration.regions
            : defaultRegions(configuration.template);

    return source
        .map((region) => region.adjust(configuration.adjustment))
        .where((region) => region.width > 0 && region.height > 0)
        .toList();
  }

  /// 将一页图片按一个或多个归一化区域裁剪并拼接。
  ///
  /// 多区域默认横向排列，适合双栏、三栏医学教材；custom + grid 可由编辑器选择网格布局。
  Future<ui.Image> cropAndCompose({
    required ui.Image source,
    required List<CropRegion> regions,
    CropLayout layout = CropLayout.horizontal,
  }) async {
    if (regions.isEmpty) {
      return source;
    }

    final normalized = regions.map((region) => region.clamp()).toList();
    final crops = <ui.Image>[];

    try {
      for (final region in normalized) {
        final width = (source.width * region.width).round().clamp(1, source.width);
        final height = (source.height * region.height).round().clamp(1, source.height);
        final left = (source.width * region.x).round().clamp(0, source.width - width);
        final top = (source.height * region.y).round().clamp(0, source.height - height);

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final src = ui.Rect.fromLTWH(
          left.toDouble(),
          top.toDouble(),
          width.toDouble(),
          height.toDouble(),
        );
        final dst = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

        canvas.drawImageRect(source, src, dst, ui.Paint());

        final picture = recorder.endRecording();
        crops.add(await picture.toImage(width, height));
      }

      if (crops.length == 1) {
        return crops.removeAt(0);
      }

      final cellWidths = crops.map((image) => image.width).toList();
      final cellHeights = crops.map((image) => image.height).toList();

      final canvasWidth = layout == CropLayout.horizontal
          ? cellWidths.fold<int>(0, (sum, value) => sum + value)
          : _gridWidth(cellWidths);
      final canvasHeight = layout == CropLayout.horizontal
          ? cellHeights.reduce((a, b) => a > b ? a : b)
          : _gridHeight(cellHeights);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      var offsetX = 0;
      var offsetY = 0;
      var rowHeight = 0;
      final columns = layout == CropLayout.horizontal
          ? crops.length
          : (crops.length <= 2 ? 2 : 3);

      for (var index = 0; index < crops.length; index++) {
        final image = crops[index];

        if (layout == CropLayout.horizontal) {
          canvas.drawImage(image, ui.Offset(offsetX.toDouble(), 0), ui.Paint());
          offsetX += image.width;
          continue;
        }

        final column = index % columns;
        final row = index ~/ columns;
        final x = _gridX(crops, column, row, columns);
        final y = _gridY(crops, column, row, columns);
        canvas.drawImage(image, ui.Offset(x.toDouble(), y.toDouble()), ui.Paint());
        rowHeight = rowHeight < image.height ? image.height : rowHeight;
        offsetY = rowHeight;
      }

      final picture = recorder.endRecording();
      return picture.toImage(canvasWidth, canvasHeight);
    } finally {
      for (final crop in crops) {
        crop.dispose();
      }
    }
  }

  int _gridWidth(List<int> widths) {
    if (widths.isEmpty) return 1;
    final columns = widths.length <= 2 ? widths.length : 3;
    var result = 0;
    for (var column = 0; column < columns; column++) {
      var width = 0;
      for (var index = column; index < widths.length; index += columns) {
        width = width < widths[index] ? widths[index] : width;
      }
      result += width;
    }
    return result;
  }

  int _gridHeight(List<int> heights) {
    if (heights.isEmpty) return 1;
    final columns = heights.length <= 2 ? heights.length : 3;
    var result = 0;
    for (var row = 0; row * columns < heights.length; row++) {
      var height = 0;
      for (var index = row * columns;
          index < heights.length && index < (row + 1) * columns;
          index++) {
        height = height < heights[index] ? heights[index] : height;
      }
      result += height;
    }
    return result;
  }

  int _gridX(List<ui.Image> images, int column, int row, int columns) {
    var x = 0;
    for (var c = 0; c < column; c++) {
      var width = 0;
      for (var index = c; index < images.length; index += columns) {
        width = width < images[index].width ? images[index].width : width;
      }
      x += width;
    }
    return x;
  }

  int _gridY(List<ui.Image> images, int column, int row, int columns) {
    var y = 0;
    for (var r = 0; r < row; r++) {
      var height = 0;
      for (var index = r * columns;
          index < images.length && index < (r + 1) * columns;
          index++) {
        height = height < images[index].height ? images[index].height : height;
      }
      y += height;
    }
    return y;
  }
}
