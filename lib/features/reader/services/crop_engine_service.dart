import 'dart:ui' as ui;

import '../models/crop_configuration.dart';

class CropEngineService {
  const CropEngineService();

  List<CropRegion> defaultRegions(CropTemplate template) {
    switch (template) {
      case CropTemplate.single:
      case CropTemplate.bookTemplate:
        return const [CropRegion(x: 0, y: 0, width: 1, height: 1)];
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

  /// pageIndex 为 0-based PDF 页；bookPage 为 1-based 书籍页。
  /// pageRanges 可以同时描述多个不连续区间，例如 12-15, 30-55。
  List<CropRegion> resolveRegions({
    required CropConfiguration configuration,
    int? pageIndex,
    int? bookPage,
    List<CropRegion>? previousRegions,
  }) {
    if (!_pageMatches(configuration, pageIndex: pageIndex, bookPage: bookPage)) {
      return const [];
    }

    final source = configuration.inheritPrevious &&
            previousRegions != null &&
            previousRegions.isNotEmpty
        ? previousRegions
        : configuration.regions.isNotEmpty
            ? configuration.regions
            : defaultRegions(configuration.template);

    // 输出顺序不再依赖用户“添加区域”的先后，而是按阅读方向排序。
    // 这样编号、横向拼接和网格排列都会符合用户的直觉。
    final ordered = [...source]
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        if (y != 0) return y;
        return a.x.compareTo(b.x);
      });

    return ordered
        .map((region) => region.adjust(configuration.adjustment))
        .where((region) => !region.excluded && region.width > 0 && region.height > 0)
        .toList();
  }

  bool _pageMatches(
    CropConfiguration configuration, {
    int? pageIndex,
    int? bookPage,
  }) {
    if (configuration.pageRanges.isNotEmpty) {
      final pageNumber = configuration.pageBasis == CropPageBasis.book
          ? bookPage
          : pageIndex == null
              ? null
              : pageIndex + 1;
      return pageNumber != null &&
          configuration.pageRanges.any((range) => range.contains(pageNumber));
    }

    if (configuration.pageBasis == CropPageBasis.book) {
      if (bookPage == null) return false;
      if (configuration.pageStart != null &&
          bookPage < configuration.pageStart!) {
        return false;
      }
      if (configuration.pageEnd != null && bookPage > configuration.pageEnd!) {
        return false;
      }
      return true;
    }

    if (pageIndex == null) return true;
    if (configuration.pageStart != null &&
        pageIndex + 1 < configuration.pageStart!) {
      return false;
    }
    if (configuration.pageEnd != null &&
        pageIndex + 1 > configuration.pageEnd!) {
      return false;
    }
    return true;
  }

  List<CropRegion> selectableRegions(List<CropRegion> regions) =>
      regions.where((region) => !region.excluded).toList();

  Future<ui.Image> cropAndCompose({
    required ui.Image source,
    required List<CropRegion> regions,
    CropLayout layout = CropLayout.horizontal,
  }) async {
    final normalized = regions
        .where((region) => !region.excluded)
        .map((region) => region.clamp())
        .where((region) => region.width > 0 && region.height > 0)
        .toList()
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        if (y != 0) return y;
        return a.x.compareTo(b.x);
      });

    if (normalized.isEmpty) return source;

    final crops = <ui.Image>[];
    try {
      for (final region in normalized) {
        final width = (source.width * region.width)
            .round()
            .clamp(1, source.width)
            .toInt();
        final height = (source.height * region.height)
            .round()
            .clamp(1, source.height)
            .toInt();
        final left = (source.width * region.x)
            .round()
            .clamp(0, source.width - width)
            .toInt();
        final top = (source.height * region.y)
            .round()
            .clamp(0, source.height - height)
            .toInt();

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            left.toDouble(),
            top.toDouble(),
            width.toDouble(),
            height.toDouble(),
          ),
          ui.Rect.fromLTWH(
            0,
            0,
            width.toDouble(),
            height.toDouble(),
          ),
          ui.Paint(),
        );
        final picture = recorder.endRecording();
        crops.add(await picture.toImage(width, height));
      }

      if (crops.length == 1) return crops.removeAt(0);

      final widths = crops.map((image) => image.width).toList();
      final heights = crops.map((image) => image.height).toList();
      final canvasWidth = layout == CropLayout.horizontal
          ? widths.fold<int>(0, (sum, value) => sum + value)
          : _gridWidth(widths);
      final canvasHeight = layout == CropLayout.horizontal
          ? heights.reduce((a, b) => a > b ? a : b)
          : _gridHeight(heights);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      var offsetX = 0;
      final columns = layout == CropLayout.horizontal
          ? crops.length
          : (crops.length <= 2 ? 2 : 3);

      for (var index = 0; index < crops.length; index++) {
        final image = crops[index];
        if (layout == CropLayout.horizontal) {
          canvas.drawImage(
            image,
            ui.Offset(offsetX.toDouble(), 0),
            ui.Paint(),
          );
          offsetX += image.width;
        } else {
          final column = index % columns;
          final row = index ~/ columns;
          canvas.drawImage(
            image,
            ui.Offset(
              _gridX(crops, column, columns).toDouble(),
              _gridY(crops, row, columns).toDouble(),
            ),
            ui.Paint(),
          );
        }
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

  int _gridX(List<ui.Image> images, int column, int columns) {
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

  int _gridY(List<ui.Image> images, int row, int columns) {
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
