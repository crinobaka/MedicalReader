import 'dart:ui' as ui;

class PageCache {
  final int capacity;

  final Map<int, ui.Image> _pages = {};

  PageCache({
    this.capacity = 3,
  }) : assert(capacity > 0);

  ui.Image? get(int pageIndex) {
    final image = _pages.remove(pageIndex);

    if (image == null) {
      return null;
    }

    _pages[pageIndex] = image;

    return image;
  }

  void put(
    int pageIndex,
    ui.Image image,
  ) {
    final existing = _pages.remove(pageIndex);

    if (identical(existing, image)) {
      _pages[pageIndex] = image;
      return;
    }

    existing?.dispose();

    _pages[pageIndex] = image;
  }

  ui.Image? remove(
    int pageIndex,
  ) {
    return _pages.remove(pageIndex);
  }

  List<ui.Image> trim() {
    final removed = <ui.Image>[];

    while (_pages.length > capacity) {
      final oldestPageIndex =
          _pages.keys.first;

      final image =
          _pages.remove(oldestPageIndex);

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

  void clearExcept(
    ui.Image? keepImage,
  ) {
    final entries =
        _pages.entries.toList();

    _pages.clear();

    for (final entry in entries) {
      final image = entry.value;

      if (identical(
        image,
        keepImage,
      )) {
        _pages[entry.key] = image;
      } else {
        image.dispose();
      }
    }
  }

  bool contains(
    int pageIndex,
  ) {
    return _pages.containsKey(
      pageIndex,
    );
  }

  int get length => _pages.length;

  Iterable<int> get pageIndexes =>
      _pages.keys;

  void dispose() {
    clear();
  }
}