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
    int radius = 3,
  }) async {
    if (_running) {
      return;
    }

    _running = true;
    final generation = ++_generation;

    try {
      // 预加载只服务于“下一次操作”，不应该为了追求命中率把 GPU
      // 内存提前塞满。默认当前页前后各 3 页，并允许调用方按设备能力调整。
      final safeRadius = radius.clamp(1, 5);
      final pages = <int>[];

      for (var offset = 1; offset <= safeRadius; offset++) {
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

          // renderPage() 返回的是调用方所有的 clone；缓存中的 L2 image
          // 仍由 ReaderEngineService 持有，因此这里只释放预加载结果。
          image.dispose();
        } catch (error, stackTrace) {
          if (generation != _generation) {
            return;
          }

          debugPrint(
            'Page preload failed: page=$pageIndex, error=$error',
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
