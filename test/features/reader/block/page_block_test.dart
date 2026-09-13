import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/block/models/page_block.dart';
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
