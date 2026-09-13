import '../models/page_block.dart';
import 'page_block_manager.dart';

class PageBlockPosition {
  const PageBlockPosition({required this.pageIndex, required this.blockIndex, required this.block});

  final int pageIndex;
  final int blockIndex;
  final PageBlock block;

  String get internalLabel => '${pageIndex + 1}(${blockIndex + 1})';
}

/// Navigation adapter that turns next/previous into virtual block turns.
class PageBlockNavigation {
  PageBlockNavigation({required this.manager});

  final PageBlockManager manager;

  Future<PageBlockPosition> first(String docId, int pageIndex) async {
    final blocks = await manager.resolve(docId, pageIndex);
    return PageBlockPosition(pageIndex: pageIndex, blockIndex: 0, block: blocks.first);
  }

  Future<PageBlockPosition?> next({
    required String docId,
    required int pageIndex,
    required int blockIndex,
    required int pageCount,
  }) async {
    final blocks = await manager.resolve(docId, pageIndex);
    if (blockIndex + 1 < blocks.length) {
      final nextIndex = blockIndex + 1;
      return PageBlockPosition(pageIndex: pageIndex, blockIndex: nextIndex, block: blocks[nextIndex]);
    }
    if (pageIndex + 1 >= pageCount) return null;
    final nextBlocks = await manager.resolve(docId, pageIndex + 1);
    return PageBlockPosition(pageIndex: pageIndex + 1, blockIndex: 0, block: nextBlocks.first);
  }

  Future<PageBlockPosition?> previous({
    required String docId,
    required int pageIndex,
    required int blockIndex,
  }) async {
    final blocks = await manager.resolve(docId, pageIndex);
    if (blockIndex > 0 && blockIndex < blocks.length) {
      final previousIndex = blockIndex - 1;
      return PageBlockPosition(pageIndex: pageIndex, blockIndex: previousIndex, block: blocks[previousIndex]);
    }
    if (pageIndex <= 0) return null;
    final previousBlocks = await manager.resolve(docId, pageIndex - 1);
    final lastIndex = previousBlocks.length - 1;
    return PageBlockPosition(
      pageIndex: pageIndex - 1,
      blockIndex: lastIndex,
      block: previousBlocks[lastIndex],
    );
  }

  Future<PageBlockPosition> fromOriginalPosition({
    required String docId,
    required int pageIndex,
    required double x,
    required double y,
  }) async {
    final blocks = await manager.resolve(docId, pageIndex);
    final index = blocks.indexWhere((b) => b.rect.contains(x, y));
    final safe = index < 0 ? 0 : index;
    return PageBlockPosition(pageIndex: pageIndex, blockIndex: safe, block: blocks[safe]);
  }
}
