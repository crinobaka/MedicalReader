import 'dart:ui' as ui;

import '../models/page_block.dart';

/// Generates non-persistent default blocks from the rendered PDF page.
///
/// The raster is the source of truth for automatic layout: stable vertical
/// whitespace gutters are detected from multiple horizontal samples, then
/// each detected reading column is partitioned independently for the current
/// viewport. Manual blocks are handled by PageBlockManager and always win.
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

    final gutters = await _findVerticalReadingGutters(image);
    final pageAspect = image.width / image.height;
    final viewportAspect = viewportWidth / viewportHeight;
    final boundaries = <double>[0, ...gutters, 1];
    final blocks = <PageBlock>[];
    var order = 1;
    var blockIndex = 0;

    for (var column = 0; column < boundaries.length - 1; column++) {
      final left = boundaries[column];
      final right = boundaries[column + 1];
      final width = right - left;
      if (width <= .04) continue;
      final rows = rowCountForRegion(
        regionWidth: width,
        pageAspect: pageAspect,
        viewportAspect: viewportAspect,
      );
      final columnBlocks = _verticalBlocks(
        docId: docId,
        pageIndex: pageIndex,
        x: left,
        width: width,
        rowCount: rows,
        orderStart: order,
        blockIndexStart: blockIndex,
      );
      blocks.addAll(columnBlocks);
      order += columnBlocks.length;
      blockIndex += columnBlocks.length;
    }

    return blocks.isEmpty ? _singlePage(docId, pageIndex) : blocks;
  }

  int rowCountForRegion({
    required double regionWidth,
    required double pageAspect,
    required double viewportAspect,
  }) {
    if (regionWidth <= 0 || pageAspect <= 0 || viewportAspect <= 0) return 1;
    final idealHeight = pageAspect * regionWidth / viewportAspect;
    if (idealHeight >= 1) return 1;
    return (1 / idealHeight).ceil().clamp(1, 8).toInt();
  }

  List<PageBlock> _verticalBlocks({
    required String docId,
    required int pageIndex,
    required double x,
    required double width,
    required int rowCount,
    required int orderStart,
    required int blockIndexStart,
  }) {
    final blocks = <PageBlock>[];
    for (var row = 0; row < rowCount; row++) {
      final top = row / rowCount;
      final bottom = (row + 1) / rowCount;
      blocks.add(
        PageBlock(
          docId: docId,
          pageIndex: pageIndex,
          blockIndex: blockIndexStart + row,
          rect: NormalizedRect(
            x: x,
            y: top,
            width: width,
            height: bottom - top,
          ),
          order: orderStart + row,
          source: PageBlockSource.defaultBlock,
        ),
      );
    }
    return blocks;
  }

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

  Future<List<double>> _findVerticalReadingGutters(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final width = image.width;
    final height = image.height;
    final stride = width * 4;
    if (width < 64 || height < 64) return const [];

    const samplesY = 28;
    final startX = (width * .08).round();
    final endX = (width * .92).round();
    final step = (width / 220).ceil();
    final positions = <int>[];
    final profiles = <List<double>>[];

    for (var sy = 1; sy <= samplesY; sy++) {
      final y = ((height - 1) * sy / (samplesY + 1)).round();
      final row = <double>[];
      for (var x = startX; x <= endX; x += step) {
        if (sy == 1) positions.add(x);
        final offset = y * stride + x * 4;
        final r = bytes[offset];
        final g = bytes[offset + 1];
        final b = bytes[offset + 2];
        final a = bytes[offset + 3];
        final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;
        row.add(a > 24 && luminance < 220 ? 1.0 : 0.0);
      }
      profiles.add(row);
    }
    if (profiles.length < 16 || positions.length < 16) return const [];

    final candidates = <int>[];
    for (var i = 3; i < positions.length - 3; i++) {
      final normalizedX = positions[i] / width;
      if (normalizedX < .15 || normalizedX > .85) continue;

      var validRows = 0;
      var sideTotal = 0.0;
      var narrowRows = 0;
      for (final profile in profiles) {
        final valley = (profile[i - 1] + profile[i] + profile[i + 1]) / 3;
        final leftStart = (i * .35).round().clamp(1, i - 1).toInt();
        final rightEnd = i + ((profile.length - i) * .65).round();
        final left = profile.sublist(leftStart, i);
        final right = profile.sublist(i + 1, rightEnd.clamp(i + 1, profile.length).toInt());
        if (left.isEmpty || right.isEmpty) continue;
        final leftInk = left.fold<double>(0, (a, b) => a + b) / left.length;
        final rightInk = right.fold<double>(0, (a, b) => a + b) / right.length;
        final sideInk = (leftInk + rightInk) / 2;
        if (sideInk < .06) continue;
        sideTotal += sideInk;
        if (valley < .20 && valley < sideInk * .52) validRows++;
        if (valley < .12 && valley < sideInk * .38) narrowRows++;
      }

      final consistency = validRows / profiles.length;
      final narrowConsistency = narrowRows / profiles.length;
      if (consistency >= .62 && narrowConsistency >= .30 && sideTotal > 0) {
        candidates.add(i);
      }
    }

    if (candidates.isEmpty) return const [];

    final groups = <List<int>>[];
    for (final candidate in candidates) {
      if (groups.isEmpty || candidate - groups.last.last > 3) {
        groups.add([candidate]);
      } else {
        groups.last.add(candidate);
      }
    }

    final gutters = <double>[];
    for (final group in groups) {
      final index = group[group.length ~/ 2];
      final x = positions[index] / width;
      if (x > .22 && x < .78) gutters.add(x.clamp(.22, .78).toDouble());
    }

    gutters.sort();
    final distinct = <double>[];
    for (final gutter in gutters) {
      if (distinct.isEmpty || gutter - distinct.last >= .10) distinct.add(gutter);
    }
    return distinct.take(3).toList(growable: false);
  }
}
