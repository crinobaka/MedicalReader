import 'dart:ui' as ui;

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';
import 'page_cache.dart';
import 'page_crop_service.dart';

class ReaderEngineService {
  final MedicalCore _core;

  final PageCache _pageCache;

  final PageCropService _cropService;

  ReaderEngineService({
    MedicalCore? core,
    PageCache? pageCache,
    PageCropService? cropService,
  }) : _core = core ?? MedicalCore(),
       _pageCache = pageCache ?? PageCache(),
       _cropService = cropService ?? const PageCropService();

  MedicalCoreDocument openDocument({required String id, required String path}) {
    _pageCache.clear();

    return _core.openBook(id: id, path: path);
  }

  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
    bool cropMargins = false,
  }) async {
    final cached = _pageCache.get(pageIndex);

    if (cached != null) {
      return cached;
    }

    final page = document.renderPage(pageIndex: pageIndex, dpi: dpi);

    ui.Image image = await MedicalCoreImage.decode(page);

    if (cropMargins) {
      final cropped = await _cropService.cropWhiteMargins(image);

      if (!identical(cropped, image)) {
        image.dispose();
        image = cropped;
      }
    }

    _pageCache.put(pageIndex, image);

    final removed = _pageCache.trim();

    for (final oldImage in removed) {
      if (!identical(oldImage, image)) {
        oldImage.dispose();
      }
    }

    return image;
  }

  void clearPageCache({ui.Image? keepImage}) {
    _pageCache.clearExcept(keepImage);
  }

  void dispose() {
    _pageCache.dispose();
  }
}
