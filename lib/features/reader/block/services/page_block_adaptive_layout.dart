import 'dart:ui' as ui;

import '../models/page_block.dart';

/// Generates non-persistent default blocks for the current screen.
///
/// The layout is deliberately conservative: it first looks for a genuine
/// vertical reading gutter in the rendered page. Only then does it create
/// independent columns. This prevents a geometric screen split from cutting
/// a two-column document into mixed reading blocks.
class PageBlockAdaptiveLayout {
  const PageBlockAdaptiveLayout();

  Future<List<PageBlock>> generate({
    required String docId,
    required int pageIndex,
    required ui.Image image,
    required double viewportWidth,
    required double viewportHeight,
  }) async {
    if (image.width <= 0 || image.height <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
      return _singlePage(docId, pageIndex);
    }

    final gutter = await _findVerticalReadingGutter(image);
    if (gutter == null) return _singlePage(docId, pageIndex);

    final leftWidth = gutter;
    final rightWidth = 1 - gutter;
    final pageAspect = image.width / image.height;
    final viewportAspect = viewportWidth / viewportHeight;
    final idealRowHeight = pageAspect * leftWidth / viewportAspect;
    final idealRightRowHeight = pageAspect * rightWidth / viewportAspect;
    final rowCount = _rowCount(idealRowHeight);
    final rightRowCount = _rowCount(idealRightRowHeight);

    final blocks = <PageBlock>[];
    var order = 1;
    for (var row = 0; row < rowCount; row++) {
      final top = row / rowCount;
      final bottom = (row + 1) / rowCount;
      blocks.add(_block(
        docId: docId,
        pageIndex: pageIndex,
        index: blocks.length,
        order: order++,
        x: 0,
        y: top,
        width: leftWidth,
        height: bottom - top,
      ));
    }
    for (var row = 0; row < rightRowCount; row++) {
      final top = row / rightRowCount;
      final bottom = (row + 1) / rightRowCount;
      blocks.add(_block(
        docId: docId,
        pageIndex: pageIndex,
        index: blocks.length,
        order: order++,
        x: gutter,
        y: top,
        width: rightWidth,
        height: bottom - top,
      ));
    }
    return blocks;
  }

  int _rowCount(double idealRowHeight) {
    if (idealRowHeight >= 1) return 1;
    if (idealRowHeight <= 0) return 1;
    return (1 / idealRowHeight).ceil().clamp(1, 8).toInt();
  }

  PageBlock _block({
    required String docId,
    required int pageIndex,
    required int index,
    required int order,
    required double x,
    required double y,
    required double width,
    required double height,
  }) => PageBlock(
        docId: docId,
        pageIndex: pageIndex,
        blockIndex: index,
        rect: NormalizedRect(x: x, y: y, width: width, height: height),
        order: order,
        source: PageBlockSource.defaultBlock,
      );

  List<PageBlock> _singlePage(String docId, int pageIndex) => [
        PageBlock(
          docId: docId,
          pageIndex: pageIndex,
          blockIndex: 0,
          rect: const NormalizedRect(x: 0, y: 0, width: 1, height: 1),
          order: 1,
          source: PageBlockSource.defaultBlock,
        ),
      ];

  Future<double?> _findVerticalReadingGutter(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final width = image.width;
    final height = image.height;
    final stride = width * 4;
    const samplesY = 18;
    final startX = (width * .30).round();
    final endX = (width * .70).round();
    if (endX - startX < 12) return null;

    double inkAt(int x) {
      var ink = 0;
      for (var sy = 1; sy <= samplesY; sy++) {
        final y = ((height - 1) * sy / (samplesY + 1)).round();
        final offset = y * stride + x * 4;
        final r = bytes[offset];
        final g = bytes[offset + 1];
        final b = bytes[offset + 2];
        final a = bytes[offset + 3];
        final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;
        if (a > 24 && luminance < 220) ink++;
      }
      return ink / samplesY;
    }

    final step = (width / 160).ceil();
    final profile = <double>[];
    final positions = <int>[];
    for (var x = startX; x <= endX; x += step) {
      positions.add(x);
      profile.add(inkAt(x));
    }
    if (profile.length < 8) return null;

    final center = profile.length / 2;
    var bestIndex = -1;
    var bestScore = double.infinity;
    for (var i = 2; i < profile.length - 2; i++) {
      final distanceFromCenter = ((i - center).abs() / center);
      if (distanceFromCenter > .35) continue;
      final valley = (profile[i - 1] + profile[i] + profile[i + 1]) / 3;
      final leftCount = i;
      final rightCount = profile.length - i - 1;
      final sideLeft = profile.sublist(0, i).fold<double>(0, (a, b) => a + b) / leftCount;
      final sideRight = profile.sublist(i + 1).fold<double>(0, (a, b) => a + b) / rightCount;
      final sideInk = (sideLeft + sideRight) / 2;
      if (sideInk < .08) continue;
      final score = valley / sideInk + distanceFromCenter * .35;
      if (valley < .18 && valley < sideInk * .48 && score < bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) return null;
    return (positions[bestIndex] / width).clamp(.35, .65).toDouble();
  }
}
