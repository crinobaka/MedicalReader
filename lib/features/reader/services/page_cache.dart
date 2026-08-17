import 'dart:ui' as ui;

/// 页面缓存的唯一键。
///
/// 不能只使用 pageIndex。
/// 因为同一页在不同 DPI 或裁边模式下，实际上是不同的渲染结果。
class PageCacheKey {
  final int pageIndex;

  final int dpi;

  final bool cropMargins;

  const PageCacheKey({
    required this.pageIndex,
    required this.dpi,
    required this.cropMargins,
  });

  @override
  bool operator ==(Object other) {
    return other is PageCacheKey &&
        other.pageIndex == pageIndex &&
        other.dpi == dpi &&
        other.cropMargins == cropMargins;
  }

  @override
  int get hashCode {
    return Object.hash(
      pageIndex,
      dpi,
      cropMargins,
    );
  }
}

/// Reader Engine 的 L2 页面缓存。
///
/// 当前版本按照 TDD：
///
/// 当前页
///   ↓
/// 前后各 5 页
///
/// 总容量默认 11 页。
///
/// 使用 LRU 思路：
///
/// 最近访问的页面放到 Map 尾部，
/// 超过容量时从 Map 头部淘汰最旧页面。
class PageCache {
  final int capacity;

  final Map<PageCacheKey, ui.Image> _pages = {};

  PageCache({
    this.capacity = 11,
  }) : assert(capacity > 0);

  /// 获取缓存页面。
  ///
  /// 返回 clone，调用方可以安全持有并 dispose。
  ui.Image? get({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
  }) {
    final key = PageCacheKey(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
    );

    final image = _pages.remove(key);

    if (image == null) {
      return null;
    }

    // 重新放到尾部，表示最近刚刚使用。
    _pages[key] = image;

    return image.clone();
  }

  /// 写入缓存。
  void put({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
    required ui.Image image,
  }) {
    final key = PageCacheKey(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
    );

    final existing = _pages.remove(key);

    if (identical(existing, image)) {
      _pages[key] = image;
      return;
    }

    existing?.dispose();

    _pages[key] = image;
  }

  /// 删除指定页面的指定渲染版本。
  ui.Image? remove({
    required int pageIndex,
    required int dpi,
    required bool cropMargins,
  }) {
    final key = PageCacheKey(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
    );

    return _pages.remove(key);
  }

  /// 按 LRU 规则淘汰旧页面。
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

  /// 清空整个缓存。
  void clear() {
    for (final image in _pages.values) {
      image.dispose();
    }

    _pages.clear();
  }

  /// 清空缓存，但保留指定 Image。
  ///
  /// 保留这个 API 是为了兼容 ReaderEngineService 现有调用方式。
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
  }) {
    return _pages.containsKey(
      PageCacheKey(
        pageIndex: pageIndex,
        dpi: dpi,
        cropMargins: cropMargins,
      ),
    );
  }

  int get length => _pages.length;

  Iterable<PageCacheKey> get keys => _pages.keys;

  void dispose() {
    clear();
  }
}