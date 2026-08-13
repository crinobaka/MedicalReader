import 'dart:ui' as ui;

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';
import 'page_cache.dart';

class ReaderEngineService {
  final MedicalCore _core;

  final PageCache _pageCache;

  ReaderEngineService({
    MedicalCore? core,
    PageCache? pageCache,
  })  : _core = core ?? MedicalCore(),
        _pageCache = pageCache ?? PageCache();

  MedicalCoreDocument openDocument({
    required String id,
    required String path,
  }) {
    _pageCache.clear();

    return _core.openBook(
      id: id,
      path: path,
    );
  }

  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
  }) async {
    final cached = _pageCache.get(pageIndex);

    if (cached != null) {
      return cached;
    }

    final page = document.renderPage(
      pageIndex: pageIndex,
      dpi: dpi,
    );

    final image = await MedicalCoreImage.decode(page);

    _pageCache.put(
      pageIndex,
      image,
    );

    final removed = _pageCache.trim();

    for (final oldImage in removed) {
      if (!identical(oldImage, image)) {
        oldImage.dispose();
      }
    }

    return image;
  }

  void clearPageCache() {
    _pageCache.clear();
  }

  void dispose() {
    _pageCache.dispose();
  }
}