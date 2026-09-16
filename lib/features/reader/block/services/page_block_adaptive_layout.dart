import 'dart:ui' as ui;

import '../models/page_block.dart';

/// Generates non-persistent default blocks for the current screen.
/// Layout is reading-order aware: detect a stable vertical gutter first,
/// then partition each reading region independently for the current viewport.
class PageBlockAdaptiveLayout {
  const PageBlockAdaptiveLayout();

  Future<List<PageBlock>> generate({
    required String docId,
    required int pageIndex,
    required ui.Image image,
    required double viewportWidth,
    required double viewportHeight,
  }) async {
    if (image.width <= 0 || image.height <= 0 || viewportWidth <= 0 || viewportHeight <= 0) return _singlePage(docId, pageIndex);
    final gutter = await _findVerticalReadingGutter(image);
    final pageAspect = image.width / image.height;
    final viewportAspect = viewportWidth / viewportHeight;
    if (gutter == null) {
      final rows = rowCountForRegion(regionWidth: 1, pageAspect: pageAspect, viewportAspect: viewportAspect);
      return _verticalBlocks(docId: docId, pageIndex: pageIndex, x: 0, width: 1, rowCount: rows, orderStart: 1, blockIndexStart: 0);
    }
    final leftWidth = gutter, rightWidth = 1 - gutter;
    final leftRows = rowCountForRegion(regionWidth: leftWidth, pageAspect: pageAspect, viewportAspect: viewportAspect);
    final rightRows = rowCountForRegion(regionWidth: rightWidth, pageAspect: pageAspect, viewportAspect: viewportAspect);
    final blocks = <PageBlock>[];
    final left = _verticalBlocks(docId: docId, pageIndex: pageIndex, x: 0, width: leftWidth, rowCount: leftRows, orderStart: 1, blockIndexStart: 0);
    blocks.addAll(left);
    blocks.addAll(_verticalBlocks(docId: docId, pageIndex: pageIndex, x: gutter, width: rightWidth, rowCount: rightRows, orderStart: left.length + 1, blockIndexStart: left.length));
    return blocks;
  }

  int rowCountForRegion({required double regionWidth, required double pageAspect, required double viewportAspect}) {
    if (regionWidth <= 0 || pageAspect <= 0 || viewportAspect <= 0) return 1;
    final idealHeight = pageAspect * regionWidth / viewportAspect;
    if (idealHeight >= 1) return 1;
    return (1 / idealHeight).ceil().clamp(1, 8).toInt();
  }

  List<PageBlock> _verticalBlocks({required String docId, required int pageIndex, required double x, required double width, required int rowCount, required int orderStart, required int blockIndexStart}) {
    final blocks = <PageBlock>[];
    for (var row = 0; row < rowCount; row++) {
      final top = row / rowCount, bottom = (row + 1) / rowCount;
      blocks.add(PageBlock(docId: docId, pageIndex: pageIndex, blockIndex: blockIndexStart + row, rect: NormalizedRect(x: x, y: top, width: width, height: bottom - top), order: orderStart + row, source: PageBlockSource.defaultBlock));
    }
    return blocks;
  }

  List<PageBlock> _singlePage(String docId, int pageIndex) => [PageBlock(docId: docId, pageIndex: pageIndex, blockIndex: 0, rect: const NormalizedRect(x: 0, y: 0, width: 1, height: 1), order: 1, source: PageBlockSource.defaultBlock)];

  Future<double?> _findVerticalReadingGutter(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final width = image.width, height = image.height, stride = width * 4;
    const samplesY = 24;
    final startX = (width * .28).round(), endX = (width * .72).round();
    if (endX - startX < 16) return null;
    final step = (width / 180).ceil();
    final positions = <int>[];
    final profiles = <List<double>>[];
    for (var sy = 1; sy <= samplesY; sy++) {
      final y = ((height - 1) * sy / (samplesY + 1)).round();
      final row = <double>[];
      for (var x = startX; x <= endX; x += step) {
        if (positions.length < row.length + 1) positions.add(x);
        final offset = y * stride + x * 4;
        final r = bytes[offset], g = bytes[offset + 1], b = bytes[offset + 2], a = bytes[offset + 3];
        final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;
        row.add(a > 24 && luminance < 220 ? 1.0 : 0.0);
      }
      profiles.add(row);
    }
    if (profiles.length < 12 || positions.length < 8) return null;
    final center = profiles.first.length / 2;
    var bestIndex = -1, bestScore = double.infinity;
    for (var i = 2; i < positions.length - 2; i++) {
      final distanceFromCenter = ((i - center).abs() / center);
      if (distanceFromCenter > .35) continue;
      var validRows = 0;
      var valleyTotal = 0.0, sideTotal = 0.0;
      for (final profile in profiles) {
        final valley = (profile[i - 1] + profile[i] + profile[i + 1]) / 3;
        final left = profile.sublist(0, i), right = profile.sublist(i + 1);
        final leftInk = left.fold<double>(0, (a, b) => a + b) / left.length;
        final rightInk = right.fold<double>(0, (a, b) => a + b) / right.length;
        final sideInk = (leftInk + rightInk) / 2;
        if (sideInk < .08) continue;
        if (valley < .20 && valley < sideInk * .52) validRows++;
        valleyTotal += valley; sideTotal += sideInk;
      }
      final consistency = validRows / profiles.length;
      if (consistency < .58 || sideTotal <= 0) continue;
      final averageValley = valleyTotal / profiles.length, averageSideInk = sideTotal / profiles.length;
      final score = averageValley / averageSideInk + distanceFromCenter * .25 - consistency * .35;
      if (score < bestScore) { bestScore = score; bestIndex = i; }
    }
    if (bestIndex < 0) return null;
    return (positions[bestIndex] / width).clamp(.32, .68).toDouble();
  }
}
