import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/block/models/page_block.dart';
import 'package:medicalreader/features/reader/block/services/page_block_adaptive_layout.dart';
import 'package:medicalreader/features/reader/block/services/page_block_manager.dart';
import 'package:medicalreader/features/reader/block/services/page_block_navigation.dart';
import 'package:medicalreader/features/reader/block/services/page_block_storage.dart';

void main() {
  late Directory temp;
  late PageBlockStorage storage;
  late PageBlockManager manager;
  late PageBlockNavigation navigation;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('medicalreader-blocks-');
    storage = PageBlockStorage(rootProvider: () async => temp);
    manager = PageBlockManager(storage: storage);
    navigation = PageBlockNavigation(manager: manager);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('default four blocks use required geometry and order', () async {
    final blocks = await manager.resolve('doc', 0);
    expect(blocks.length, 4);
    expect(blocks[0].rect.toJson(), {'x': 0, 'y': 0, 'w': .5, 'h': .5});
    expect(blocks[1].rect.toJson(), {'x': 0, 'y': .5, 'w': .5, 'h': .5});
    expect(blocks[2].rect.toJson(), {'x': .5, 'y': 0, 'w': .5, 'h': .5});
    expect(blocks[3].rect.toJson(), {'x': .5, 'y': .5, 'w': .5, 'h': .5});
    expect(blocks.map((b) => b.order), [1, 2, 3, 4]);
  });

  test('adaptive row count follows viewport without exceeding eight pieces', () {
    const layout = PageBlockAdaptiveLayout();
    expect(
      layout.rowCountForRegion(
        regionWidth: .45,
        pageAspect: .707,
        viewportAspect: .56,
      ),
      2,
    );
    expect(
      layout.rowCountForRegion(
        regionWidth: 1,
        pageAspect: 1.4,
        viewportAspect: .56,
      ),
      3,
    );
    expect(
      layout.rowCountForRegion(
        regionWidth: 1,
        pageAspect: .4,
        viewportAspect: 3,
      ),
      1,
    );
    expect(
      layout.rowCountForRegion(
        regionWidth: 1,
        pageAspect: 10,
        viewportAspect: .1,
      ),
      8,
    );
  });

  test('adaptive layout recognizes three raster columns', () async {
    final layout = const PageBlockAdaptiveLayout();
    final image = await _makeThreeColumnImage();
    addTearDown(image.dispose);

    final blocks = await layout.generate(
      docId: 'doc',
      pageIndex: 4,
      image: image,
      viewportWidth: 360,
      viewportHeight: 640,
    );

    expect(blocks.length, greaterThanOrEqualTo(3));
    expect(blocks.map((b) => b.pageIndex).toSet(), {4});
    expect(blocks.map((b) => b.blockIndex).toList(), orderedEquals(List.generate(blocks.length, (i) => i)));
    expect(blocks.map((b) => b.order).toList(), orderedEquals(List.generate(blocks.length, (i) => i + 1)));

    final firstColumn = blocks.first.rect.x;
    final columnStarts = <double>[];
    for (final block in blocks) {
      if (columnStarts.isEmpty || (block.rect.x - columnStarts.last).abs() > .08) {
        columnStarts.add(block.rect.x);
      }
    }
    expect(columnStarts.length, 3);
    expect(firstColumn, closeTo(0.0, .03));
    expect(columnStarts[1], closeTo(1 / 3, .06));
    expect(columnStarts[2], closeTo(2 / 3, .06));
  });

  test('navigation crosses page boundary by block', () async {
    final next = await navigation.next(docId: 'doc', pageIndex: 0, blockIndex: 3, pageCount: 10);
    expect(next!.pageIndex, 1);
    expect(next.blockIndex, 0);

    final previous = await navigation.previous(docId: 'doc', pageIndex: 1, blockIndex: 0);
    expect(previous!.pageIndex, 0);
    expect(previous.blockIndex, 3);
  });

  test('manual blocks override defaults and preserve arbitrary count/order', () async {
    await manager.saveManual('doc', 0, const [
      NormalizedRect(x: .5, y: 0, width: .5, height: .5),
      NormalizedRect(x: 0, y: 0, width: .5, height: .5),
      NormalizedRect(x: .5, y: .5, width: .5, height: .5),
    ]);
    final blocks = await manager.resolve('doc', 0);
    expect(blocks.length, 3);
    expect(blocks.every((b) => b.source == PageBlockSource.manual), isTrue);
    expect(blocks[0].rect.x, .5);
    expect(blocks[1].rect.x, 0);
  });

  test('original page position maps to containing block', () async {
    final position = await navigation.fromOriginalPosition(docId: 'doc', pageIndex: 0, x: .75, y: .25);
    expect(position.blockIndex, 2);
  });

  test('manual scroll percent is persisted', () async {
    await manager.saveManual('doc', 0, const [NormalizedRect(x: 0, y: 0, width: 1, height: .5)]);
    final block = (await manager.resolve('doc', 0)).single;
    await manager.saveScrollPercent(block, .5);
    final restored = (await storage.loadManual('doc', 0))!.single;
    expect(restored.scrollPercent, .5);
  });
}

Future<ui.Image> _makeThreeColumnImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final white = ui.Paint()..color = const ui.Color(0xffffffff);
  final ink = ui.Paint()..color = const ui.Color(0xff111111);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 300, 300), white);
  canvas.drawRect(const ui.Rect.fromLTWH(18, 12, 72, 276), ink);
  canvas.drawRect(const ui.Rect.fromLTWH(114, 12, 72, 276), ink);
  canvas.drawRect(const ui.Rect.fromLTWH(210, 12, 72, 276), ink);
  final picture = recorder.endRecording();
  return picture.toImage(300, 300);
}
