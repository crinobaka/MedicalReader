import 'dart:ui' as ui;

class PageCache {
  final int capacity;

  final Map<int, ui.Image> _pages = {};

  PageCache({
    this.capacity = 3,
  }) : assert(capacity > 0);

  ui.Image? get(int pageIndex) {
    return _pages[pageIndex];
  }

  void put(
    int pageIndex,
    ui.Image image,
  ) {
    final existing = _pages[pageIndex];

    if (identical(existing, image)) {
      return;
    }

    _pages[pageIndex] = image;

    existing?.dispose();
  }

  ui.Image? remove(int pageIndex) {
    return _pages.remove(pageIndex);
  }

  List<ui.Image> trim() {
    final removed = <ui.Image>[];

    while (_pages.length > capacity) {
      final oldestPageIndex = _pages.keys.first;

      final image = _pages.remove(oldestPageIndex);

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

  bool contains(int pageIndex) {
    return _pages.containsKey(pageIndex);
  }

  int get length => _pages.length;

  Iterable<int> get pageIndexes => _pages.keys;

  void dispose() {
    clear();
  }
}