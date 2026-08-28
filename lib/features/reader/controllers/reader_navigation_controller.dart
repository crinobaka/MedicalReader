import 'package:flutter/foundation.dart';

/// Owns page-index navigation policy for the reader.
///
/// Navigation is intentionally independent from PDF rendering. The host can
/// call [move] and then decide when/how to render the requested page.
class ReaderNavigationController extends ChangeNotifier {
  ReaderNavigationController({int pageCount = 0, int currentPage = 0})
      : _pageCount = pageCount,
        _currentPage = _clampPage(currentPage, pageCount);

  int _pageCount;
  int _currentPage;

  int get pageCount => _pageCount;
  int get currentPage => _currentPage;
  bool get canGoPrevious => _currentPage > 0;
  bool get canGoNext => _currentPage + 1 < _pageCount;

  void setPageCount(int count, {int? currentPage}) {
    final nextCount = count < 0 ? 0 : count;
    final nextPage = _clampPage(currentPage ?? _currentPage, nextCount);
    if (nextCount == _pageCount && nextPage == _currentPage) return;
    _pageCount = nextCount;
    _currentPage = nextPage;
    notifyListeners();
  }

  bool goTo(int page) {
    final next = _clampPage(page, _pageCount);
    if (next == _currentPage) return false;
    _currentPage = next;
    notifyListeners();
    return true;
  }

  bool next() => goTo(_currentPage + 1);

  bool previous() => goTo(_currentPage - 1);

  bool first() => goTo(0);

  bool last() => goTo(_pageCount - 1);

  static int _clampPage(int page, int pageCount) {
    if (pageCount <= 0) return 0;
    return page.clamp(0, pageCount - 1);
  }
}
