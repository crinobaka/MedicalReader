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

    existing?.dispose();

    _pages[pageIndex] = image;

    _trim();
  }

  void remove(int pageIndex) {
    final image = _pages.remove(pageIndex);

    image?.dispose();
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

  void _trim() {
    while (_pages.length > capacity) {
      final oldestPageIndex = _pages.keys.first;

      final image = _pages.remove(oldestPageIndex);

      image?.dispose();
    }
  }
}