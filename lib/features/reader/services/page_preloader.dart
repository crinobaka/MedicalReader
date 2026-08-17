import 'package:flutter/foundation.dart';

import '../../../core/ffi/medical_core.dart';
import 'reader_engine_service.dart';

class PagePreloader {
  final ReaderEngineService _readerEngine;

  bool _running = false;

  int _generation = 0;

  PagePreloader({required ReaderEngineService readerEngine})
    : _readerEngine = readerEngine;

  Future<void> preloadAround({
    required MedicalCoreDocument document,
    required int currentPage,
    required int pageCount,
    int dpi = 150,
    bool cropMargins = false,
  }) async {
    if (_running) {
      return;
    }

    _running = true;

    final generation = ++_generation;

    try {
      // ------------------------------------------------------------
      // L2 预加载策略：
      //
      // 当前页前后各 5 页。
      //
      // 例如当前页 = 100：
      //
      // 95 96 97 98 99
      //       ↓
      //      100
      //       ↑
      // 101 102 103 104 105
      //
      // 当前页本身不需要重复渲染，
      // 因为 ReaderPage 已经负责首屏渲染。
      // ------------------------------------------------------------
      final pages = <int>[];

      for (var offset = 1; offset <= 5; offset++) {
        pages.add(currentPage - offset);
        pages.add(currentPage + offset);
      }

      for (final pageIndex in pages) {
        if (generation != _generation) {
          return;
        }

        if (pageIndex < 0 || pageIndex >= pageCount) {
          continue;
        }

        try {
          final image = await _readerEngine.renderPage(
            document: document,
            pageIndex: pageIndex,
            dpi: dpi,
            cropMargins: cropMargins,
          );

          // renderPage() 返回的是 clone。
          // 预加载器自己不需要持有它，所以立即释放。
          image.dispose();
        } catch (error, stackTrace) {
          if (generation != _generation) {
            return;
          }

          debugPrint(
            'Page preload failed: '
            'page=$pageIndex, '
            'error=$error',
          );

          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } finally {
      if (generation == _generation) {
        _running = false;
      }
    }
  }

  void cancel() {
    _generation++;
    _running = false;
  }
}
