import 'dart:async';

import '../../../core/ffi/medical_core.dart';
import 'reader_engine_service.dart';

class PagePreloader {
  final ReaderEngineService _readerEngine;

  bool _running = false;

  PagePreloader({
    required ReaderEngineService readerEngine,
  }) : _readerEngine = readerEngine;

  Future<void> preloadAround({
    required MedicalCoreDocument document,
    required int currentPage,
    required int pageCount,
    int dpi = 150,
  }) async {
    if (_running) {
      return;
    }

    _running = true;

    try {
      final pages = <int>[
        currentPage - 1,
        currentPage + 1,
      ];

      for (final pageIndex in pages) {
        if (pageIndex < 0 || pageIndex >= pageCount) {
          continue;
        }

        try {
          await _readerEngine.renderPage(
            document: document,
            pageIndex: pageIndex,
            dpi: dpi,
          );
        } catch (_) {
          // 预加载失败不能影响当前阅读。
        }
      }
    } finally {
      _running = false;
    }
  }
}