import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/page_block.dart';
import '../services/page_block_manager.dart';
import '../services/page_block_navigation.dart';

class PageBlockController extends ChangeNotifier {
  PageBlockController({required this.docId, required int pageCount, PageBlockManager? manager})
      : pageCount = pageCount < 1 ? 1 : pageCount,
        manager = manager ?? PageBlockManager() {
    navigation = PageBlockNavigation(manager: this.manager);
  }

  final String docId;
  int pageCount;
  final PageBlockManager manager;
  late final PageBlockNavigation navigation;

  bool enabled = false;
  bool loading = false;
  bool editing = false;
  int currentPageIndex = 0;
  int currentBlockIndex = 0;
  PageBlock? currentBlock;
  Object? error;

  String get uiPageLabel => '${currentPageIndex + 1}';
  String get internalBlockLabel => currentBlock == null
      ? uiPageLabel
      : '${currentPageIndex + 1}(${currentBlockIndex + 1})';

  bool get canPrevious => enabled && currentBlock != null && (currentPageIndex > 0 || currentBlockIndex > 0);

  Future<bool> get canNext async {
    if (!enabled || currentBlock == null) return false;
    final blocks = await manager.resolve(docId, currentPageIndex);
    return currentBlockIndex < blocks.length - 1 || currentPageIndex < pageCount - 1;
  }

  void configurePageCount(int value) {
    final next = value < 1 ? 1 : value;
    if (next == pageCount) return;
    pageCount = next;
    currentPageIndex = currentPageIndex.clamp(0, pageCount - 1).toInt();
  }

  Future<void> enable({int? pageIndex}) async {
    if (enabled && pageIndex == null) return;
    enabled = true;
    loading = true;
    error = null;
    if (pageIndex != null) currentPageIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    notifyListeners();
    try {
      final position = await navigation.first(docId, currentPageIndex);
      _setPosition(position);
      unawaited(_prefetch());
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Rebuilds only automatic blocks using the real page raster and viewport.
  /// Persisted manual blocks always remain the source of truth.
  Future<void> adaptCurrentPage({
    required ui.Image image,
    required double viewportWidth,
    required double viewportHeight,
  }) async {
    if (!enabled || viewportWidth <= 0 || viewportHeight <= 0) return;
    final page = currentPageIndex;
    final oldBlock = currentBlock;
    manager.configureLayout(
      image: image,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final blocks = await manager.resolve(docId, page);
    if (!enabled || currentPageIndex != page || blocks.isEmpty) return;

    if (oldBlock != null && oldBlock.source == PageBlockSource.manual) {
      final index = blocks.indexWhere((b) => b.blockIndex == oldBlock.blockIndex);
      if (index >= 0) {
        currentBlockIndex = index;
        currentBlock = blocks[index];
      }
    } else {
      final safeIndex = currentBlockIndex.clamp(0, blocks.length - 1).toInt();
      currentBlockIndex = safeIndex;
      currentBlock = blocks[safeIndex];
    }
    notifyListeners();
  }

  Future<void> disable() async {
    enabled = false;
    loading = false;
    editing = false;
    currentBlock = null;
    manager.clear();
    notifyListeners();
  }

  Future<void> moveToPage(int pageIndex, {double? originalX, double? originalY}) async {
    if (!enabled) return;
    currentPageIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final position = originalX == null || originalY == null
          ? await navigation.first(docId, currentPageIndex)
          : await navigation.fromOriginalPosition(docId: docId, pageIndex: currentPageIndex, x: originalX, y: originalY);
      _setPosition(position);
      unawaited(_prefetch());
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> next() async {
    if (!enabled || loading || currentBlock == null) return false;
    loading = true;
    notifyListeners();
    try {
      final position = await navigation.next(docId: docId, pageIndex: currentPageIndex, blockIndex: currentBlockIndex, pageCount: pageCount);
      if (position == null) return false;
      _setPosition(position);
      unawaited(_prefetch());
      return true;
    } catch (e) {
      error = e;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> previous() async {
    if (!enabled || loading || currentBlock == null) return false;
    loading = true;
    notifyListeners();
    try {
      final position = await navigation.previous(docId: docId, pageIndex: currentPageIndex, blockIndex: currentBlockIndex);
      if (position == null) return false;
      _setPosition(position);
      unawaited(_prefetch());
      return true;
    } catch (e) {
      error = e;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveManualBlocks(List<NormalizedRect> rects) async {
    await manager.saveManual(docId, currentPageIndex, rects);
    _setPosition(await navigation.first(docId, currentPageIndex));
    notifyListeners();
  }

  Future<void> saveOrderedBlocks(List<PageBlock> blocks) async {
    final previousRect = currentBlock?.rect;
    await manager.saveManualBlocks(docId, currentPageIndex, blocks);
    final refreshed = await manager.resolve(docId, currentPageIndex);
    if (refreshed.isEmpty) {
      currentBlock = null;
      currentBlockIndex = 0;
    } else {
      var targetIndex = currentBlockIndex;
      if (previousRect != null) {
        targetIndex = refreshed.indexWhere((b) {
          final r = b.rect;
          return r.x == previousRect.x && r.y == previousRect.y && r.width == previousRect.width && r.height == previousRect.height;
        });
        if (targetIndex < 0) targetIndex = currentBlockIndex;
      }
      final safeIndex = targetIndex.clamp(0, refreshed.length - 1).toInt();
      currentBlockIndex = safeIndex;
      currentBlock = refreshed[safeIndex];
    }
    notifyListeners();
  }

  Future<void> updateScrollPercent(double percent) async {
    final block = currentBlock;
    if (block == null) return;
    final next = block.copyWith(scrollPercent: percent);
    currentBlock = next;
    if (block.source == PageBlockSource.manual) await manager.saveScrollPercent(next, percent);
    notifyListeners();
  }

  void clearSessionCache() => manager.clear();

  void setEditing(bool value) {
    editing = value;
    notifyListeners();
  }

  void _setPosition(PageBlockPosition position) {
    currentPageIndex = position.pageIndex;
    currentBlockIndex = position.blockIndex;
    currentBlock = position.block;
    error = null;
  }

  Future<void> _prefetch() => manager.prefetchDefaults(docId, currentPageIndex, pageCount);
}
