import 'dart:ui' as ui;

/// 页面缓存的唯一键。
///
/// 同一页在不同 DPI、裁边模式或自定义裁剪配置下都是不同结果。
class PageCacheKey {
  final int pageIndex;
  final int dpi;
  final bool cropMargins;
  final String cropSignature;

  const PageCacheKey({
    required this.pageIndex,
    required this.dpi,
    required this.cropMargins,
    this.cropSignature = '',
  });

  @override
  bool operator ==(Object other) {
    return other is PageCacheKey &&
        other.pageIndex == pageIndex &&
        other.dpi == dpi &&
        other.cropMargins == cropMargins &&
        other.cropSignature == cropSignature;
  }

  @override
  int get hashCode {
    return Object.hash(
      pageIndex,
      dpi,
      cropMargins,
      cropSignature,
    );
  }
}

/// Reader Engine 的 L2 页面缓存。
///
/// 当前页前后各 5 页，总容量默认 11 页。
/// 使用 LRU：最近访问的页面放到 Map 尾部，超过容量淘汰最旧页面。
class PageCache {
  final int capacity;
  final Map<PageCacheKey, ui.Image> _pages = {};

  PageCache({this.capacity = 11}) : assert(capacity > 0);

  ui.Image? get({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
    String cropSignature = '',
  }) {
    final key = PageCacheKey(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
      cropSignature: cropSignature,
    );

    final image = _pages.remove(key);
    if (image == null) {
      return null;
    }

    _pages[key] = image;
    return image.clone();
  }

  void put({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
    String cropSignature = '',
    required ui.Image image,
  }) {
    final key = PageCacheKey(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
      cropSignature: cropSignature,
    );

    final existing = _pages.remove(key);
    if (identical(existing, image)) {
      _pages[key] = image;
      return;
    }

    existing?.dispose();
    _pages[key] = image;
  }

  ui.Image? remove({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
    String cropSignature = '',
  }) {
    return _pages.remove(
      PageCacheKey(
        pageIndex: pageIndex,
        dpi: dpi,
        cropMargins: cropMargins,
        cropSignature: cropSignature,
      ),
    );
  }

  List<ui.Image> trim() {
    final removed = <ui.Image>[];

    while (_pages.length > capacity) {
      final oldestKey = _pages.keys.first;
      final image = _pages.remove(oldestKey);
      if (image != null) {
        removed.add(image);
      }
    }

    return removed;
  }

  void clear() {
    for (final image in _pages.values) {
      image.dispose();
    }
    _pages.clear();
  }

  void clearExcept(ui.Image? keepImage) {
    final entries = _pages.entries.toList();
    _pages.clear();

    for (final entry in entries) {
      final image = entry.value;
      if (identical(image, keepImage)) {
        _pages[entry.key] = image;
      } else {
        image.dispose();
      }
    }
  }

  bool contains({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
    String cropSignature = '',
  }) {
    return _pages.containsKey(
      PageCacheKey(
        pageIndex: pageIndex,
        dpi: dpi,
        cropMargins: cropMargins,
        cropSignature: cropSignature,
      ),
    );
  }

  int get length => _pages.length;

  Iterable<PageCacheKey> get keys => _pages.keys;

  void dispose() => clear();
}
