import 'dart:collection';
import 'dart:ui' as ui;

import '../models/page_block.dart';
import 'page_block_adaptive_layout.dart';
import 'page_block_storage.dart';

class PageBlockManager {
  PageBlockManager({PageBlockStorage? storage, this.maxFuturePages = 5}) : storage = storage ?? PageBlockStorage();

  final PageBlockStorage storage;
  final int maxFuturePages;
  final LinkedHashMap<String, List<PageBlock>> _cache = LinkedHashMap();
  final PageBlockAdaptiveLayout _adaptiveLayout = const PageBlockAdaptiveLayout();

  ui.Image? _layoutImage;
  int? _layoutPageIndex;
  double? _viewportWidth;
  double? _viewportHeight;
  String? _layoutSignature;

  void configureLayout({
    required int pageIndex,
    required ui.Image image,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (viewportWidth <= 0 || viewportHeight <= 0) return;
    final signature = '$pageIndex:${identityHashCode(image)}:${image.width}x${image.height}:$viewportWidth:$viewportHeight';
    if (signature == _layoutSignature) return;
    _layoutSignature = signature;
    _layoutPageIndex = pageIndex;
    _layoutImage = image;
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
    _cache.removeWhere((key, blocks) => blocks.isNotEmpty && blocks.first.source == PageBlockSource.defaultBlock);
  }

  Future<List<PageBlock>> resolve(String docId, int pageIndex) async {
    final manual = await storage.loadManual(docId, pageIndex);
    if (manual != null && manual.isNotEmpty) {
      _put(_key(docId, pageIndex), manual);
      return manual;
    }
    final key = _key(docId, pageIndex);
    final cached = _cache[key];
    if (cached != null) {
      _touch(key);
      return cached;
    }

    final image = _layoutImage;
    final viewportWidth = _viewportWidth;
    final viewportHeight = _viewportHeight;
    final blocks = image != null && _layoutPageIndex == pageIndex && viewportWidth != null && viewportHeight != null
        ? await _adaptiveLayout.generate(docId: docId, pageIndex: pageIndex, image: image, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        : defaultFour(docId, pageIndex);
    _put(key, blocks);
    return blocks;
  }

  Future<bool> hasManual(String docId, int pageIndex) async => (await storage.loadManual(docId, pageIndex))?.isNotEmpty ?? false;

  List<PageBlock> defaultFour(String docId, int pageIndex) => [
        _defaultBlock(docId, pageIndex, 0, 0, 0),
        _defaultBlock(docId, pageIndex, 1, 0, .5),
        _defaultBlock(docId, pageIndex, 2, .5, 0),
        _defaultBlock(docId, pageIndex, 3, .5, .5),
      ];

  Future<void> saveManual(String docId, int pageIndex, List<NormalizedRect> rects) async {
    final blocks = [
      for (var i = 0; i < rects.length; i++)
        PageBlock(docId: docId, pageIndex: pageIndex, blockIndex: i, rect: rects[i].normalized(), order: i + 1, source: PageBlockSource.manual),
    ];
    await storage.saveManual(docId, pageIndex, blocks);
    _put(_key(docId, pageIndex), blocks);
  }

  Future<void> saveManualBlocks(String docId, int pageIndex, List<PageBlock> blocks) async {
    await storage.saveManual(docId, pageIndex, blocks);
    final saved = await storage.loadManual(docId, pageIndex);
    if (saved != null) _put(_key(docId, pageIndex), saved);
  }

  Future<void> saveScrollPercent(PageBlock block, double percent) async {
    final current = await storage.loadManual(block.docId, block.pageIndex);
    if (current == null) return;
    final updated = [for (final b in current) b.blockIndex == block.blockIndex ? b.copyWith(scrollPercent: percent) : b];
    await storage.saveManual(block.docId, block.pageIndex, updated);
    _put(_key(block.docId, block.pageIndex), updated);
  }

  Future<void> prefetchDefaults(String docId, int currentPage, int pageCount) async => _trim(currentPage: currentPage, docId: docId);

  void clear() {
    _cache.clear();
    _layoutSignature = null;
    _layoutImage = null;
    _layoutPageIndex = null;
  }

  void clearDocument(String docId) => _cache.removeWhere((key, _) => key.startsWith('$docId:'));
  void _put(String key, List<PageBlock> blocks) { _cache.remove(key); _cache[key] = List.unmodifiable(blocks); }
  void _touch(String key) { final value = _cache.remove(key); if (value != null) _cache[key] = value; }
  void _trim({required int currentPage, required String docId}) {
    final allowed = <String>{for (var p = currentPage; p <= currentPage + maxFuturePages; p++) _key(docId, p)};
    _cache.removeWhere((key, _) => key.startsWith('$docId:') && !allowed.contains(key));
  }
  String _key(String docId, int pageIndex) => '$docId:$pageIndex';
  PageBlock _defaultBlock(String docId, int pageIndex, int index, double x, double y) => PageBlock(docId: docId, pageIndex: pageIndex, blockIndex: index, rect: NormalizedRect(x: x, y: y, width: .5, height: .5), order: index + 1, source: PageBlockSource.defaultBlock);
}
