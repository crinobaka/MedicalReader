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
  int get hashCode => Object.hash(
        pageIndex,
        dpi,
        cropMargins,
        cropSignature,
      );
}

/// Reader Engine 的 L2 页面缓存。
///
/// 同时使用“页数上限”和“估算像素内存上限”。
/// 仅限制页数在高 DPI 页面上并不可靠：一张 300 DPI 的医学扫描页
/// 就可能占用几十 MB。这里按 RGBA 4 bytes/pixel 做保守估算，
/// 超出预算时从最旧页面开始淘汰。
class PageCache {
  final int capacity;
  final int maxBytes;
  final Map<PageCacheKey, ui.Image> _pages = {};
  int _estimatedBytes = 0;

  PageCache({
    this.capacity = 11,
    this.maxBytes = 64 * 1024 * 1024,
  })  : assert(capacity > 0),
        assert(maxBytes > 0);

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

    if (existing != null) {
      _estimatedBytes -= _estimateBytes(existing);
      existing.dispose();
    }

    _pages[key] = image;
    _estimatedBytes += _estimateBytes(image);
  }

  ui.Image? remove({
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
    if (image != null) {
      _estimatedBytes -= _estimateBytes(image);
    }
    return image;
  }

  List<ui.Image> trim() {
    final removed = <ui.Image>[];

    while (_pages.length > capacity ||
        (_pages.length > 1 && _estimatedBytes > maxBytes)) {
      final oldestKey = _pages.keys.first;
      final image = _pages.remove(oldestKey);
      if (image != null) {
        _estimatedBytes -= _estimateBytes(image);
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
    _estimatedBytes = 0;
  }

  void clearExcept(ui.Image? keepImage) {
    final entries = _pages.entries.toList();
    _pages.clear();
    _estimatedBytes = 0;

    for (final entry in entries) {
      final image = entry.value;
      if (identical(image, keepImage)) {
        _pages[entry.key] = image;
        _estimatedBytes += _estimateBytes(image);
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

  int get estimatedBytes => _estimatedBytes;

  Iterable<PageCacheKey> get keys => _pages.keys;

  void dispose() => clear();

  int _estimateBytes(ui.Image image) => image.width * image.height * 4;
}
