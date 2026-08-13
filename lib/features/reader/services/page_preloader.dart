import 'package:flutter/foundation.dart';

import '../../../core/ffi/medical_core.dart';
import 'reader_engine_service.dart';

class PagePreloader {
  final ReaderEngineService _readerEngine;

  bool _running = false;

  int _generation = 0;

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

    final generation = ++_generation;

    try {
      final pages = <int>[
        currentPage - 1,
        currentPage + 1,
      ];

      for (final pageIndex in pages) {
        if (generation != _generation) {
          return;
        }

        if (pageIndex < 0 || pageIndex >= pageCount) {
          continue;
        }

        try {
          await _readerEngine.renderPage(
            document: document,
            pageIndex: pageIndex,
            dpi: dpi,
          );
        } catch (error, stackTrace) {
          if (generation != _generation) {
            return;
          }

          debugPrint(
            'Page preload failed: '
            'page=$pageIndex, '
            'error=$error',
          );

          debugPrintStack(
            stackTrace: stackTrace,
          );
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